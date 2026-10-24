//@ pragma UseQApplication
import Quickshell
import "./modules"

ShellRoot {
    Bar {
        screen: Quickshell.screens.find(s => s.name === "DP-3") ?? null
    }

    ToastLayer {
        screen: Quickshell.screens.find(s => s.name === "DP-3") ?? null
    }
}
