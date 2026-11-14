pragma Singleton
import QtQuick
import Quickshell

// Single choke point for "which app opens X". Resolved in an sh wrapper at
// launch: PATH checks need no synchronous Process, and the bar (started
// from Hyprland autostart) may lack $TERMINAL.
QtObject {
    // $TERMINAL (word-split, first word must be on PATH), else the first
    // terminal found on PATH. gnome-terminal/kgx/ptyxis take "--" as the
    // command separator, everything else "-e". Mirrors noctalia's
    // terminal_launch.cpp.
    readonly property string _terminalScript: [
        't="${TERMINAL:-}"',
        'if [ -z "$t" ] || ! command -v ${t%% *} >/dev/null 2>&1; then',
        '  t=""',
        '  for c in x-terminal-emulator ghostty kitty alacritty foot konsole gnome-terminal kgx ptyxis xterm; do',
        '    command -v "$c" >/dev/null 2>&1 && t="$c" && break',
        '  done',
        'fi',
        'if [ -z "$t" ]; then',
        '  command -v notify-send >/dev/null 2>&1 && notify-send -u critical "No terminal found" "Set $TERMINAL or install a terminal emulator"',
        '  exit 1',
        'fi',
        'case "${t%% *}" in gnome-terminal|kgx|ptyxis) sep=--;; *) sep=-e;; esac',
        'exec $t $sep "$@"'
    ].join("\n")

    function terminalCommand(argv) {
        return ["sh", "-c", _terminalScript, "sh", ...argv];
    }

    function runInTerminal(argv) {
        Quickshell.execDetached(terminalCommand(argv));
    }

    function openUrl(url) {
        Quickshell.execDetached(["xdg-open", String(url)]);
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", String(path)]);
    }

    // Select `path` in the file manager via org.freedesktop.FileManager1,
    // falling back to opening its parent directory.
    function revealInFileManager(path) {
        Quickshell.execDetached(["sh", "-c",
            'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "[\'file://$1\']" "" >/dev/null 2>&1 || xdg-open "$(dirname "$1")"',
            "sh", String(path)]);
    }
}
