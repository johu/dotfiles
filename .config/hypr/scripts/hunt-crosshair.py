#!/usr/bin/env python3
# Center-screen crosshair overlay (white dot, subtle black outline) drawn via
# the wlr-layer-shell protocol, so it renders above exclusive-fullscreen
# windows on both Hyprland and KWin/Plasma. Click-through (empty input
# region) and keyboard-transparent, so it never intercepts game input - a
# plain compositor-level overlay window, same category as the other Hunt
# display tweaks: it never touches the game's own process.
#
# Input region must be set via Gdk.Surface.set_input_region() *after*
# window.present(), not on the "realize" signal: gtk_layer_init_for_window()
# only turns the window into an actual layer surface once mapped, so
# anything set before present() targets the pre-map surface and gets reset.
# Also note Gtk4LayerShell.is_supported() is unreliable on some builds;
# get_protocol_version() > 0 is the trustworthy check.
import math
import sys

import cairo
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gtk
from gi.repository import Gtk4LayerShell as LayerShell

DOT_RADIUS = 1.6
OUTLINE_RADIUS = 3.0


def on_draw(_area, cr, width, height, _data=None):
    cx, cy = width / 2, height / 2

    cr.set_source_rgba(0, 0, 0, 0.85)
    cr.arc(cx, cy, OUTLINE_RADIUS, 0, 2 * math.pi)
    cr.fill()

    cr.set_source_rgba(1, 1, 1, 1.0)
    cr.arc(cx, cy, DOT_RADIUS, 0, 2 * math.pi)
    cr.fill()


def on_activate(app):
    if LayerShell.get_protocol_version() == 0:
        sys.stderr.write("hunt-crosshair: compositor has no layer-shell support\n")
        app.quit()
        return

    window = Gtk.ApplicationWindow(application=app)
    LayerShell.init_for_window(window)
    LayerShell.set_namespace(window, "hunt-crosshair")
    LayerShell.set_layer(window, LayerShell.Layer.OVERLAY)
    LayerShell.set_keyboard_mode(window, LayerShell.KeyboardMode.NONE)
    # Stretch across the whole output and ignore other layers' exclusive
    # zones (e.g. the bar), so the dot lands on the true screen center
    # rather than the center of whatever space is left over.
    for edge in (
        LayerShell.Edge.LEFT,
        LayerShell.Edge.RIGHT,
        LayerShell.Edge.TOP,
        LayerShell.Edge.BOTTOM,
    ):
        LayerShell.set_anchor(window, edge, True)
    LayerShell.set_exclusive_zone(window, -1)

    window.set_decorated(False)

    css = Gtk.CssProvider()
    css.load_from_data(b"window { background-color: transparent; }")
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    area = Gtk.DrawingArea()
    area.set_draw_func(on_draw)
    window.set_child(area)

    window.present()
    surface = window.get_surface()
    if surface is not None:
        surface.set_input_region(cairo.Region())


app = Gtk.Application(application_id="dev.johu.hunt-crosshair")
app.connect("activate", on_activate)
app.run(None)
