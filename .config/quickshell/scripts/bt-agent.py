#!/usr/bin/env python3
"""BlueZ pairing agent (org.bluez.Agent1) driven by QML over stdio.

Quickshell.Bluetooth registers no agent, so BlueZ cannot ask anyone for a
PIN / passkey / confirmation when pairing a new device. This script is that
agent: it answers BlueZ only after QML has replied, and does nothing else
(scanning, pair(), connect(), forget() stay native in Quickshell.Bluetooth).

Run it only while a pairing flow is open: BlueZ has one default agent.

Protocol, one JSON object per line.
stdout (to QML):
  {"event":"ready"}                       registered as default agent
  {"event":"error","msg":"..."}           registration failed etc. (fatal ones
                                          are followed by exit)
  {"event":"confirm","id":N,"device":"/org/bluez/..","name":"..","passkey":123456}
  {"event":"authorize","id":N,"device":..,"name":..}
  {"event":"service","id":N,"device":..,"name":..,"uuid":".."}
  {"event":"pin","id":N,"device":..,"name":..}
  {"event":"passkey","id":N,"device":..,"name":..}
  {"event":"display","device":..,"name":..,"passkey":123456,"entered":3}
  {"event":"displaypin","device":..,"name":..,"pin":"0000"}
  {"event":"cancel"}                      pending request withdrawn / timed out
stdin (from QML), `id` must match the pending request or the line is ignored:
  {"reply":"accept","id":N}               confirm / authorize / service
  {"reply":"reject","id":N}
  {"reply":"pin","id":N,"value":"0000"}
  {"reply":"passkey","id":N,"value":123456}
Rules: one pending request at a time (a new one rejects the old one), reject
on timeout (BT_AGENT_TIMEOUT seconds, default 30) and on stdin EOF, never
accept without an explicit reply. Logs go to stderr only.

Test hook: BT_AGENT_BUS=session exports the agent on the session bus without
registering it with BlueZ, so the methods can be called with busctl --user.
"""

import json
import os
import signal
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

try:  # GLib.unix_signal_add is deprecated in newer PyGObject
    from gi.repository import GLibUnix

    unix_signal_add = GLibUnix.signal_add
except ImportError:
    unix_signal_add = GLib.unix_signal_add

BUS_NAME = "org.bluez"
AGENT_IFACE = "org.bluez.Agent1"
MANAGER_IFACE = "org.bluez.AgentManager1"
AGENT_PATH = "/org/quickshell/BtAgent"
CAPABILITY = "KeyboardDisplay"
TIMEOUT = int(os.environ.get("BT_AGENT_TIMEOUT", "30"))
TEST_MODE = os.environ.get("BT_AGENT_BUS") == "session"


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def log(*a):
    print("bt-agent:", *a, file=sys.stderr, flush=True)


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus
        self.pending = None  # dict: id, kind, ok, err, timer
        self.next_id = 1

    # -- helpers ---------------------------------------------------------

    def name_of(self, path):
        try:
            if TEST_MODE:  # we own org.bluez there: a sync call would deadlock
                raise RuntimeError
            props = dbus.Interface(
                self.bus.get_object(BUS_NAME, str(path)),
                "org.freedesktop.DBus.Properties",
            )
            return str(props.Get("org.bluez.Device1", "Alias"))
        except Exception:
            return str(path).rsplit("/", 1)[-1].replace("_", ":")[4:]

    def begin(self, kind, ok, err, **fields):
        """Start a request; a still-pending one is rejected first."""
        self.finish(error=Rejected("superseded"), notify=False)
        rid = self.next_id
        self.next_id += 1
        timer = GLib.timeout_add_seconds(TIMEOUT, self.on_timeout, rid)
        self.pending = {"id": rid, "kind": kind, "ok": ok, "err": err, "timer": timer}
        emit({"event": kind, "id": rid, **fields})

    def finish(self, result=None, error=None, notify=True):
        p = self.pending
        if p is None:
            return
        self.pending = None
        GLib.source_remove(p["timer"])
        if error is not None:
            p["err"](error)
        else:
            p["ok"](*result) if result is not None else p["ok"]()
        if notify and error is not None:
            emit({"event": "cancel"})

    def on_timeout(self, rid):
        if self.pending and self.pending["id"] == rid:
            log("request", rid, "timed out, rejecting")
            self.pending["timer"] = 0  # already fired; do not remove again
            p = self.pending
            self.pending = None
            p["err"](Rejected("timeout"))
            emit({"event": "cancel"})
        return False

    def handle_reply(self, msg):
        p = self.pending
        if p is None or msg.get("id") != p["id"]:
            log("ignoring reply without matching pending request:", msg)
            return
        r = msg.get("reply")
        kind = p["kind"]
        try:
            if r == "reject":
                self.finish(error=Rejected("rejected by user"))
            elif r == "accept" and kind in ("confirm", "authorize", "service"):
                self.finish()
            elif r == "pin" and kind == "pin":
                self.finish(result=(dbus.String(str(msg["value"])),))
            elif r == "passkey" and kind == "passkey":
                self.finish(result=(dbus.UInt32(int(msg["value"])),))
            else:
                log("reply", r, "does not fit pending", kind)
        except (KeyError, ValueError) as e:
            log("bad reply:", e)

    # -- org.bluez.Agent1 ------------------------------------------------

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        log("released by bluez")
        self.finish(error=Canceled("released"))

    @dbus.service.method(
        AGENT_IFACE, in_signature="o", out_signature="s", async_callbacks=("ok", "err")
    )
    def RequestPinCode(self, device, ok, err):
        self.begin("pin", ok, err, device=str(device), name=self.name_of(device))

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit({"event": "displaypin", "device": str(device),
              "name": self.name_of(device), "pin": str(pincode)})

    @dbus.service.method(
        AGENT_IFACE, in_signature="o", out_signature="u", async_callbacks=("ok", "err")
    )
    def RequestPasskey(self, device, ok, err):
        self.begin("passkey", ok, err, device=str(device), name=self.name_of(device))

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit({"event": "display", "device": str(device),
              "name": self.name_of(device), "passkey": int(passkey),
              "entered": int(entered)})

    @dbus.service.method(
        AGENT_IFACE, in_signature="ou", out_signature="", async_callbacks=("ok", "err")
    )
    def RequestConfirmation(self, device, passkey, ok, err):
        self.begin("confirm", ok, err, device=str(device),
                   name=self.name_of(device), passkey=int(passkey))

    @dbus.service.method(
        AGENT_IFACE, in_signature="o", out_signature="", async_callbacks=("ok", "err")
    )
    def RequestAuthorization(self, device, ok, err):
        self.begin("authorize", ok, err, device=str(device), name=self.name_of(device))

    @dbus.service.method(
        AGENT_IFACE, in_signature="os", out_signature="", async_callbacks=("ok", "err")
    )
    def AuthorizeService(self, device, uuid, ok, err):
        self.begin("service", ok, err, device=str(device),
                   name=self.name_of(device), uuid=str(uuid))

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        log("cancelled by bluez")
        p = self.pending
        if p is not None:
            self.pending = None
            GLib.source_remove(p["timer"])
            p["err"](Canceled("cancelled"))
        emit({"event": "cancel"})


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    bus = dbus.SessionBus() if TEST_MODE else dbus.SystemBus()
    if TEST_MODE:
        _name = dbus.service.BusName(BUS_NAME, bus)  # so busctl --user can call it
    agent = Agent(bus)
    manager = None

    def shutdown(*_):
        agent.finish(error=Rejected("agent exiting"), notify=False)
        if manager is not None:
            try:
                manager.UnregisterAgent(AGENT_PATH)
            except Exception as e:
                log("unregister failed:", e)
        loop.quit()
        return False

    if not TEST_MODE:
        try:
            manager = dbus.Interface(
                bus.get_object(BUS_NAME, "/org/bluez"), MANAGER_IFACE
            )
            manager.RegisterAgent(AGENT_PATH, CAPABILITY)
            manager.RequestDefaultAgent(AGENT_PATH)
        except dbus.DBusException as e:
            name = e.get_dbus_name()
            # AlreadyExists: another agent (e.g. blueman-applet) holds the slot.
            emit({"event": "error", "msg": f"{name}: {e.get_dbus_message()}"})
            log("register failed:", e)
            sys.exit(1)
    emit({"event": "ready"})

    def on_stdin(fd, cond):
        if cond & GLib.IO_IN:
            line = sys.stdin.readline()
            if line:
                try:
                    agent.handle_reply(json.loads(line))
                except json.JSONDecodeError:
                    log("bad json:", line.strip())
                return True
        # EOF / hangup: QML went away, nobody can answer any more.
        shutdown()
        return False

    GLib.io_add_watch(
        sys.stdin.fileno(), GLib.PRIORITY_DEFAULT,
        GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin,
    )
    for sig in (signal.SIGTERM, signal.SIGINT):
        unix_signal_add(GLib.PRIORITY_HIGH, sig, shutdown)
    loop.run()


if __name__ == "__main__":
    main()
