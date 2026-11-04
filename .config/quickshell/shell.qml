//@ pragma UseQApplication
import Quickshell
import "./modules"

ShellRoot {
    Bar {
        screen: Env.targetScreen()
    }

    ToastLayer {
        screen: Env.targetScreen()
    }
}
