import QtQuick
import "GentooParse.js" as P

// Statistics page: package counts per repository (installed and in the repos), EAPI
// distribution, largest categories, slowest builds. Read from /var/db/pkg, the repos and
// emerge.log (cached for 6 h by the helper).
Item {
    id: page

    property var view

    readonly property var st: view.statsD
    readonly property string note: "read from /var/db/pkg and the repos" + (st.checkedEpoch ? ", checked " + view.ageText(st.checkedEpoch) : "")
    property bool treeCats: false

    readonly property int gap: 22
    readonly property int topH: Math.round((height - gap) * 0.5)
    readonly property int cw: Math.floor((width - 2 * gap) / 3)
    readonly property var eapiColors: [Theme.blue, Theme.surface2, Theme.green, Theme.mauve]
    readonly property var cats: treeCats ? st.categoriesTree : st.categories
    readonly property int catMax: Math.max(1, cats.reduce((m, c) => Math.max(m, c[1]), 1))
    readonly property int slowMax: Math.max(1, st.slowest.reduce((m, c) => Math.max(m, c.seconds), 1))
    readonly property int eapi7Installed: (st.eapiInstalled.find(e => e[0] === "EAPI 7") ?? ["", 0])[1]

    readonly property var hints: [[
            { keys: ["Tab"], text: treeCats ? "categories: tree" : "categories: installed" },
            { keys: ["r"], text: "refresh" },
            { keys: ["Esc"], text: "back" }
        ]]

    function handleKey(event) {
        if (event.key === Qt.Key_Tab) {
            page.treeCats = !page.treeCats;
            return true;
        }
        return false;
    }

    component RepoCard: GentooCard {
        id: rc

        property var entries: []
        property int total: 0
        property string caption: ""
        property bool pct: false

        readonly property var parts: entries.filter(r => r[1] > 0)
        readonly property int ds: Math.min(height - 90, 190)

        GentooDonut {
            x: 24
            y: Math.round(50 + (parent.height - 70 - rc.ds) / 2)
            width: rc.ds
            height: rc.ds
            thickness: Math.round(rc.ds * 0.15)
            center: P.kText(rc.total)
            caption: rc.caption
            slices: rc.parts.map(r => ({ value: r[1], color: GentooStyle.repoColor(r[0]) }))
        }

        Column {
            x: rc.ds + 52
            y: 56
            width: parent.width - rc.ds - 76

            Repeater {
                model: rc.parts.slice(0, 8)

                Item {
                    required property var modelData

                    width: parent.width
                    height: 27

                    Rectangle {
                        y: 9
                        width: 10
                        height: 10
                        radius: 5
                        color: GentooStyle.repoColor(modelData[0])
                    }

                    GText {
                        x: 20
                        width: parent.width - 210
                        height: parent.height
                        text: modelData[0]
                    }

                    GText {
                        x: parent.width - (rc.pct ? 190 : 110)
                        width: rc.pct ? 110 : 110
                        height: parent.height
                        horizontalAlignment: Text.AlignRight
                        text: P.countText(modelData[1])
                        color: view.dim
                        size: Theme.fontSize - 1
                    }

                    GText {
                        visible: rc.pct
                        x: parent.width - 76
                        width: 76
                        height: parent.height
                        horizontalAlignment: Text.AlignRight
                        text: P.pct(modelData[1], rc.total)
                        color: GentooStyle.faint
                        size: Theme.fontSize - 1
                    }
                }
            }
        }
    }

    RepoCard {
        x: 0
        y: 0
        width: page.cw
        height: page.topH
        title: "Installed by repository"
        accent: Theme.blue
        entries: page.st.installedByRepo
        total: page.st.installed
        caption: "packages"
    }

    RepoCard {
        x: page.cw + page.gap
        y: 0
        width: page.cw
        height: page.topH
        title: "Ebuilds by repository"
        accent: Theme.green
        entries: page.st.treeByRepo
        total: page.st.treeTotal
        caption: "ebuilds"
        pct: true
    }

    // ---- EAPI ----
    GentooCard {
        id: eapiCard

        x: 2 * (page.cw + page.gap)
        y: 0
        width: page.cw
        height: page.topH
        title: "EAPI distribution"
        accent: Theme.mauve

        Repeater {
            model: [{ label: "Installed (" + page.st.installed + ")", data: page.st.eapiInstalled }, { label: "::gentoo tree (" + P.countText(page.st.eapiTree.reduce((a, e) => a + e[1], 0)) + ")", data: page.st.eapiTree }]

            Item {
                required property var modelData
                required property int index

                id: blk

                readonly property int total: modelData.data.reduce((a, e) => a + e[1], 0)

                x: 24
                y: 56 + index * 110
                width: eapiCard.width - 48
                height: 100

                GText {
                    height: 22
                    text: modelData.label
                    color: view.dim
                    size: Theme.fontSize - 1
                }

                Row {
                    y: 30
                    width: parent.width
                    height: 24

                    Repeater {
                        model: parent.parent.modelData.data

                        Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width * modelData[1] / Math.max(1, parent.parent.total)
                            height: 24
                            color: page.eapiColors[index % page.eapiColors.length]
                        }
                    }
                }

                Row {
                    y: 62
                    spacing: 22

                    Repeater {
                        model: parent.parent.modelData.data

                        Row {
                            required property var modelData
                            required property int index

                            spacing: 6

                            Rectangle {
                                y: 6
                                width: 10
                                height: 10
                                radius: 5
                                color: page.eapiColors[index % page.eapiColors.length]
                            }

                            GText {
                                height: 22
                                text: modelData[0] + "  " + P.pct(modelData[1], blk.total)
                                color: view.dim
                                size: Theme.fontSize - 1
                            }
                        }
                    }
                }
            }
        }

        GText {
            visible: page.eapi7Installed > 0
            x: 24
            y: parent.height - 38
            width: parent.width - 48
            height: 24
            text: "EAPI 7 is deprecated, " + page.eapi7Installed + " installed use it"
            color: Theme.yellow
            size: Theme.fontSize - 1
        }
    }

    // ---- categories ----
    GentooCard {
        x: 0
        y: page.topH + page.gap
        width: Math.round((page.width - page.gap) * 0.52)
        height: page.height - page.topH - page.gap
        title: page.treeCats ? "Largest categories (::gentoo tree)" : "Largest categories (installed)"
        accent: Theme.maroon

        Column {
            x: 24
            y: 56
            width: parent.width - 48

            Repeater {
                model: page.cats

                Item {
                    required property var modelData

                    width: parent.width
                    height: 34

                    GText {
                        width: 170
                        height: parent.height
                        text: modelData[0]
                        size: Theme.fontSize
                    }

                    Rectangle {
                        x: 180
                        y: 8
                        width: Math.max(4, (parent.width - 260) * modelData[1] / page.catMax)
                        height: 18
                        radius: 4
                        color: Theme.maroon
                    }

                    GText {
                        x: 180 + Math.max(4, (parent.width - 260) * modelData[1] / page.catMax) + 10
                        height: parent.height
                        text: P.countText(modelData[1])
                        color: view.dim
                        size: Theme.fontSize - 1
                    }
                }
            }
        }
    }

    // ---- slowest builds ----
    GentooCard {
        x: Math.round((page.width - page.gap) * 0.52) + page.gap
        y: page.topH + page.gap
        width: page.width - x
        height: page.height - page.topH - page.gap
        title: "Slowest builds (average, all time)"
        accent: Theme.lavender

        Column {
            x: 24
            y: 56
            width: parent.width - 48

            Repeater {
                model: page.st.slowest

                Item {
                    required property var modelData

                    width: parent.width
                    height: 34

                    GText {
                        width: 300
                        height: parent.height
                        text: modelData.atom.replace(/^cross-([^/]{1,18})[^/]*\//, "cross-$1…/")
                        size: Theme.fontSize
                    }

                    Rectangle {
                        x: 310
                        y: 8
                        width: Math.max(4, (parent.width - 310 - 190) * modelData.seconds / page.slowMax)
                        height: 18
                        radius: 4
                        color: Theme.lavender
                    }

                    GText {
                        x: 310 + Math.max(4, (parent.width - 310 - 190) * modelData.seconds / page.slowMax) + 10
                        height: parent.height
                        text: P.longDuration(modelData.seconds) + " · " + modelData.count + "×"
                        color: view.dim
                        size: Theme.fontSize - 1
                    }
                }
            }
        }

        GText {
            visible: !Dependencies.has("qlop")
            x: 24
            y: 56
            width: parent.width - 48
            height: 24
            text: Dependencies.why("qlop")
            color: Theme.yellow
        }
    }
}
