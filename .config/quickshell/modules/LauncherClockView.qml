import QtQuick
import Quickshell
import "ClockParse.js" as P

// Clock view of the launcher: an overview (Now, day / night map, Timers, Alarms, Stopwatch) and one
// page per card (Timers, Alarms, World, Stopwatch), same flow as the Gentoo view: Enter opens a page,
// Esc goes back, q closes the launcher. All state lives in ClockService, so timers, alarms and the
// stopwatch keep running while this view is closed. While something rings the view shows the
// ringing screen instead. Same contract as the other views.
Item {
    id: view

    property int textRender: Text.NativeRendering
    // Handed to the page components (a property named "root" would shadow Launcher.qml's root).
    readonly property var host: view

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1800
    readonly property int preferredHeight: 1000

    // "overview" | "timers" | "alarms" | "world" | "stopwatch"
    property string page: "overview"
    property int sel: 0
    // an action the next page should start with: "newTimer" | "newAlarm" | "newZone"
    property string pending: ""

    readonly property color dim: GentooStyle.dim
    readonly property bool ringingNow: ClockService.ringing.length > 0
    readonly property string shownPage: view.ringingNow ? "ringing" : view.page

    onTextRenderChanged: GentooStyle.textRender = view.textRender
    Component.onCompleted: GentooStyle.textRender = view.textRender

    function openPage(name) {
        view.page = name;
    }

    function handleEscape() {
        if (pageLoader.item && pageLoader.item.handleEscape && pageLoader.item.handleEscape())
            return true;
        // a ringing screen is answered with Enter; Esc just leaves (the ring goes on)
        if (view.ringingNow || view.page === "overview")
            return false;
        view.page = "overview";
        return true;
    }

    readonly property var hints: pageLoader.item ? pageLoader.item.hints : []

    function handleKey(event) {
        if (pageLoader.item && pageLoader.item.handleKey(event))
            return true;
        if (event.key === Qt.Key_Q) {
            view.leaveRequested();
            return true;
        }
        return false;
    }

    // ---- header ----
    readonly property var pageTitles: ({ timers: "Timers", alarms: "Alarms", world: "World", stopwatch: "Stopwatch" })

    Image {
        id: logo

        x: 0
        y: 6
        width: 46
        height: 46
        source: Quickshell.shellPath("assets/clock-logo.svg")
        sourceSize: Qt.size(92, 92)
        fillMode: Image.PreserveAspectFit
        opacity: 0.85
    }

    GText {
        visible: view.shownPage !== "overview" && view.shownPage !== "ringing"
        x: logo.width + 14
        y: 6
        height: 46
        text: "›"
        color: view.dim
        size: Theme.fontSize + 12
    }

    GText {
        visible: view.shownPage !== "overview" && view.shownPage !== "ringing"
        x: logo.width + 48
        y: 6
        height: 46
        text: view.pageTitles[view.shownPage] ?? ""
        color: Theme.text
        size: Theme.fontSize + 12
        strong: true
    }

    GText {
        x: Math.round(parent.width * 0.4)
        y: 6
        width: Math.round(parent.width * 0.6)
        height: 46
        horizontalAlignment: Text.AlignRight
        text: pageLoader.item?.note ?? ""
        color: view.dim
        size: Theme.fontSize
    }

    Loader {
        id: pageLoader

        x: 0
        y: 66
        width: view.width
        height: view.height - 66
        sourceComponent: ({ overview: overviewC, ringing: ringingC, timers: timersC, alarms: alarmsC, world: worldC, stopwatch: stopwatchC })[view.shownPage] ?? overviewC
    }

    Component {
        id: overviewC

        ClockOverview {
            view: host
        }
    }

    Component {
        id: ringingC

        ClockRingingPage {
            view: host
        }
    }

    Component {
        id: timersC

        ClockTimersPage {
            view: host
        }
    }

    Component {
        id: alarmsC

        ClockAlarmsPage {
            view: host
        }
    }

    Component {
        id: worldC

        ClockWorldPage {
            view: host
        }
    }

    Component {
        id: stopwatchC

        ClockStopwatchPage {
            view: host
        }
    }
}
