//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./modules"

ShellRoot {
    Component.onCompleted: Dependencies.start()

    Bar {
        screen: Env.targetScreen()
    }

    ToastLayer {
        screen: Env.targetScreen()
    }
}
