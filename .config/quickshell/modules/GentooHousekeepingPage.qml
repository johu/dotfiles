import QtQuick
import "GentooParse.js" as P

// Housekeeping page: six cards (config files, depclean, distfiles, kernels, packages that
// left the tree, failed builds). Slow checks are cached by the helper and the cards say
// how old they are. Cleaning hands off to a terminal.
Item {
    id: page

    property var view

    readonly property var hk: view.hkD
    readonly property string note: "slow checks are cached" + (hk.checkedEpoch ? " · checked " + view.ageText(hk.checkedEpoch) : "")

    readonly property int gap: 22
    readonly property int cw: Math.floor((width - 2 * gap) / 3)
    readonly property int ch: Math.floor((height - gap) / 2)
    // Kernels outside the keep rule (see P.kernelRemovals), never the running one.
    readonly property var oldKernels: hk.kernels.list.filter(k => P.kernelRemovals(hk.kernels.list, hk.kernels.running).indexOf(k.version) >= 0)

    readonly property var hints: [[
            { keys: ["c"], text: "clean distfiles" },
            { keys: ["d"], text: "dispatch-conf" },
            { keys: ["K"], text: "remove old kernels", ghost: page.oldKernels.length === 0 },
            { keys: ["r"], text: "refresh" },
            { keys: ["Esc"], text: "back" }
        ]]

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_C:
            view.inTerminal("sudo eclean-dist --interactive");
            return true;
        case Qt.Key_D:
            view.inTerminal("sudo dispatch-conf");
            return true;
        case Qt.Key_K:
            if ((event.modifiers & Qt.ShiftModifier) && page.oldKernels.length > 0)
                view.inTerminal(page.kernelCommand(page.oldKernels.map(k => k.version)));
            return true;
        }
        return false;
    }

    // Runs eclean-kernel's own removal (kernel-install prerm, files, bootloader update) on exactly the
    // chosen versions: its `-n N` can only drop the oldest ones, but the keep rule also removes
    // kernels in the middle (a 7.3.x between the kept 7.3 and 7.2 kernels).
    readonly property string kernelCode: "import sys, os; import ecleankernel.__main__ as m; rm = set(a for a in sys.argv[1:] if not a.startswith(\"-\")); rm.discard(os.uname().release); m.get_removal_list = lambda kernels, **kw: {k: [\"outside the keep rule\"] for k in kernels if k.version in rm}; sys.exit(m.main([a for a in sys.argv[1:] if a.startswith(\"-\")]))"

    function kernelCommand(versions) {
        const v = versions.join(" ");
        return "CODE='" + page.kernelCode + "'; sudo python3 -I -c \"$CODE\" -p " + v + "; printf 'Remove these kernels? [y/N] '; read a; [ \"$a\" = y ] && sudo python3 -I -c \"$CODE\" " + v;
    }

    function ok(cond) {
        return cond ? "ok" : "warn";
    }

    // ---- 0: config files ----
    GentooCard {
        x: 0
        y: 0
        width: page.cw
        height: page.ch
        title: "Config files"
        accent: Theme.green

        GentooIcon {
            x: 24
            y: 56
            size: 26
            kind: page.ok(page.hk.cfgCount === 0)
        }

        GText {
            x: 60
            y: 54
            width: parent.width - 80
            height: 30
            text: page.hk.cfgCount === 0 ? "none waiting" : page.hk.cfgCount + " waiting"
            color: page.hk.cfgCount === 0 ? Theme.green : Theme.yellow
            strong: true
            size: Theme.fontSize + 4
        }

        GText {
            x: 24
            y: 100
            width: parent.width - 48
            height: 22
            text: page.hk.cfgCount === 0 ? "No ._cfg0000_* files in /etc." : "Updated files waiting for a merge:"
            size: Theme.fontSize
        }

        Column {
            x: 24
            y: 126
            width: parent.width - 48

            Repeater {
                model: page.hk.cfgFiles.slice(0, 5)

                GText {
                    required property string modelData

                    width: parent.width
                    height: 22
                    text: modelData.replace(/\._cfg\d+_/, "")
                    color: Theme.yellow
                    size: Theme.fontSize - 1
                }
            }
        }

        GText {
            x: 24
            y: parent.height - 70
            width: parent.width - 48
            height: 48
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: page.hk.cfgCount === 0 ? "When some exist: d runs dispatch-conf in your terminal." : "d runs dispatch-conf in your terminal."
            color: view.dim
            size: Theme.fontSize - 1
        }
    }

    // ---- 1: depclean ----
    GentooCard {
        x: page.cw + page.gap
        y: 0
        width: page.cw
        height: page.ch
        title: "Depclean"
        accent: Theme.green

        GentooIcon {
            x: 24
            y: 56
            size: 26
            kind: page.ok(page.hk.depclean.remove === 0)
        }

        GText {
            x: 60
            y: 54
            width: parent.width - 80
            height: 30
            text: page.hk.depclean.remove === 0 ? "nothing to remove" : page.hk.depclean.remove + " to remove"
            color: page.hk.depclean.remove === 0 ? Theme.green : Theme.yellow
            strong: true
            size: Theme.fontSize + 4
        }

        Column {
            x: 24
            y: 100
            width: parent.width - 48

            GentooKV {
                label: "World"
                value: String(page.hk.depclean.world)
                labelWidth: 120
            }

            GentooKV {
                label: "System"
                value: String(page.hk.depclean.system)
                labelWidth: 120
            }

            GentooKV {
                label: "Required"
                value: String(page.hk.depclean.required)
                labelWidth: 120
            }
        }

        Column {
            x: 24
            y: 200
            width: parent.width - 48

            Repeater {
                model: page.hk.depclean.packages.slice(0, 4)

                GText {
                    required property string modelData

                    width: parent.width
                    height: 22
                    text: modelData
                    color: Theme.yellow
                    size: Theme.fontSize - 1
                }
            }
        }

        GText {
            x: 24
            y: parent.height - 38
            width: parent.width - 48
            height: 24
            text: "emerge -p --depclean" + (page.hk.checkedEpoch ? " · checked " + view.ageText(page.hk.checkedEpoch) : "")
            color: view.dim
            size: Theme.fontSize - 1
        }
    }

    // ---- 2: distfiles ----
    GentooCard {
        x: 2 * (page.cw + page.gap)
        y: 0
        width: page.cw
        height: page.ch
        title: "Distfiles"
        accent: Theme.yellow

        GText {
            x: 24
            y: 46
            width: parent.width - 48
            height: 60
            text: P.bytesText(page.hk.distfiles.totalBytes)
            size: 44
            strong: true
            elide: Text.ElideNone
        }

        Column {
            x: 24
            y: 116
            width: parent.width - 48

            GentooKV {
                label: "Reclaimable"
                value: page.hk.distfiles.files > 0 ? P.bytesText(page.hk.distfiles.reclaimBytes) + " (" + page.hk.distfiles.files + " files)" : "nothing"
                valueColor: page.hk.distfiles.files > 0 ? Theme.yellow : Theme.green
                labelWidth: 185
            }

            GentooKV {
                label: "Binary packages"
                value: page.hk.binpkgs.clean ? "clean" : P.bytesText(page.hk.binpkgs.reclaimBytes) + " (" + page.hk.binpkgs.files + " files)"
                valueColor: page.hk.binpkgs.clean ? Theme.green : Theme.yellow
                labelWidth: 185
            }

            GentooKV {
                label: "Build leftovers"
                value: page.hk.failed.length === 0 ? "none" : page.hk.failed.length + " in " + page.hk.tmpdir
                valueColor: page.hk.failed.length === 0 ? Theme.green : Theme.yellow
                labelWidth: 185
            }
        }

        GText {
            x: 24
            y: parent.height - 70
            width: parent.width - 48
            height: 48
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: Dependencies.has("eclean-dist") ? "c runs eclean-dist in your terminal (it asks before deleting)" : Dependencies.why("eclean-dist")
            color: Dependencies.has("eclean-dist") ? view.dim : Theme.yellow
            size: Theme.fontSize - 1
        }
    }

    // ---- 3: kernels ----
    GentooCard {
        x: 0
        y: page.ch + page.gap
        width: page.cw
        height: page.ch
        title: "Kernels"
        accent: Theme.maroon

        GentooIcon {
            x: 24
            y: 56
            size: 26
            kind: page.hk.kernels.reboot ? "warn" : "ok"
        }

        GText {
            x: 60
            y: 54
            width: parent.width - 80
            height: 30
            text: page.hk.kernels.running.replace(/-gentoo.*$/, "") + (page.hk.kernels.reboot ? " running, " + page.hk.kernels.latest.replace(/-gentoo.*$/, "") + " installed" : " running and latest")
            color: page.hk.kernels.reboot ? Theme.yellow : Theme.green
            strong: true
            size: Theme.fontSize + 2
        }

        GText {
            x: 24
            y: 96
            height: 22
            text: "Reboot needed: " + (page.hk.kernels.reboot ? "yes" : "no")
            size: Theme.fontSize
        }

        Column {
            x: 24
            y: 130
            width: parent.width - 48

            Repeater {
                model: page.hk.kernels.list.slice(0, 6)

                Item {
                    required property var modelData

                    width: parent.width
                    height: 28

                    Rectangle {
                        y: 9
                        width: 10
                        height: 10
                        radius: 5
                        color: modelData.running ? Theme.green : Theme.surface2
                    }

                    GText {
                        x: 22
                        width: 130
                        height: parent.height
                        text: modelData.version.replace(/-gentoo.*$/, "")
                    }

                    GText {
                        x: 160
                        width: 90
                        height: parent.height
                        text: modelData.bytes > 0 ? P.bytesText(modelData.bytes) : "modules only"
                        color: view.dim
                        size: Theme.fontSize - 1
                    }

                    GText {
                        x: 270
                        width: 100
                        height: parent.height
                        text: modelData.running ? "running" : (page.oldKernels.some(k => k.version === modelData.version) ? "remove" : "keep")
                        color: modelData.running ? Theme.green : (page.oldKernels.some(k => k.version === modelData.version) ? Theme.yellow : view.dim)
                        size: Theme.fontSize - 1
                    }
                }
            }
        }

        GText {
            visible: page.oldKernels.length > 0
            x: 24
            y: parent.height - 34
            width: parent.width - 48
            height: 22
            text: "K removes the " + page.oldKernels.length + " marked (asks first)"
            color: view.dim
            size: Theme.fontSize - 1
        }
    }

    // ---- 4: not in the tree ----
    GentooCard {
        x: page.cw + page.gap
        y: page.ch + page.gap
        width: page.cw
        height: page.ch
        title: "Not in the tree anymore"
        accent: Theme.yellow

        GText {
            x: 24
            y: 54
            width: parent.width - 48
            height: 30
            text: page.hk.notInTree.length === 0 ? "everything is still in a repo" : page.hk.notInTree.length + (page.hk.notInTree.length === 1 ? " installed package" : " installed packages")
            color: page.hk.notInTree.length === 0 ? Theme.green : Theme.yellow
            strong: true
            size: Theme.fontSize + 4
        }

        GText {
            visible: page.hk.notInTree.length > 0
            x: 24
            y: 92
            width: parent.width - 48
            height: 22
            text: "Installed, but no ebuild is left in any repo."
            color: view.dim
            size: Theme.fontSize - 1
        }

        Column {
            x: 24
            y: 126
            width: parent.width - 48

            Repeater {
                model: page.hk.notInTree.slice(0, 6)

                GText {
                    required property string modelData

                    width: parent.width
                    height: 28
                    text: modelData
                    size: Theme.fontSize
                }
            }
        }

        GText {
            visible: page.hk.notInTree.some(n => view.pretendText.indexOf(n.replace(/^[^/]+\//, "").replace(/-\d.*$/, "")) >= 0 && view.pretend.hasConflict)
            x: 24
            y: parent.height - 34
            width: parent.width - 48
            height: 22
            text: "one of them is a side of the update conflict"
            color: Theme.yellow
            size: Theme.fontSize - 1
        }
    }

    // ---- 5: build problems ----
    GentooCard {
        x: 2 * (page.cw + page.gap)
        y: page.ch + page.gap
        width: page.cw
        height: page.ch
        title: "Last build problems"
        accent: page.hk.failed.length === 0 ? Theme.green : Theme.red

        GentooIcon {
            x: 24
            y: 56
            size: 26
            kind: page.hk.failed.length === 0 ? "ok" : "error"
        }

        GText {
            x: 60
            y: 54
            width: parent.width - 80
            height: 30
            text: page.hk.failed.length === 0 ? "no failed build" : page.hk.failed[0].atom
            color: page.hk.failed.length === 0 ? Theme.green : Theme.red
            strong: true
            size: Theme.fontSize + 4
        }

        GText {
            x: 24
            y: 100
            width: parent.width - 48
            height: 22
            text: page.hk.failed.length === 0 ? page.hk.tmpdir + " is empty." : "build.log (last lines):"
            size: Theme.fontSize
        }

        Column {
            x: 24
            y: 128
            width: parent.width - 48

            Repeater {
                model: page.hk.failed.length > 0 ? page.hk.failed[0].tail.slice(-5) : []

                GText {
                    required property string modelData

                    width: parent.width
                    height: 22
                    text: modelData
                    size: Theme.fontSize - 2
                }
            }
        }

        GText {
            visible: page.hk.failed.length === 0
            x: 24
            y: 130
            width: parent.width - 48
            height: 48
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: "A failed build would show the package, the last log lines and where the log file is."
            color: view.dim
            size: Theme.fontSize - 1
        }

        GText {
            visible: page.hk.failed.length > 0
            x: 24
            y: parent.height - 34
            width: parent.width - 48
            height: 22
            text: page.hk.failed.length > 0 ? page.hk.failed[0].log : ""
            color: view.dim
            size: Theme.fontSize - 2
        }
    }
}
