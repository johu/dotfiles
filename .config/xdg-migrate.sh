#!/usr/bin/env bash
#
# xdg-migrate.sh — replay the ~/docs/xdg-cleanup migrations on another machine.
#
# Moves legacy $HOME dotdirs to the XDG locations declared in ~/.config/env.sh
# (plus the native-XDG browser profiles and GnuPG). Safe and idempotent: a
# migration only runs when the legacy source exists and the XDG target does not,
# and it is skipped while the owning app is running.
#
# Dry run by default — nothing is moved until you pass --apply.
#
#   ~/.config/xdg-migrate.sh            # show what would happen
#   ~/.config/xdg-migrate.sh --apply    # actually move
#
# Not handled here (deliberately): residue deletions (machine-specific, risky),
# context-mode (CONTEXT_MODE_DATA_DIR not in env.sh), pi-quotas (hardcoded
# upstream bug). See ~/docs/xdg-cleanup for those.

set -u

APPLY=0
case "${1:-}" in
	--apply) APPLY=1 ;;
	-h|--help) sed -n '2,22p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
	"") ;;
	*) echo "unknown arg: $1 (use --apply or --help)" >&2; exit 2 ;;
esac

ENV_FILE="$HOME/.config/env.sh"
[ -r "$ENV_FILE" ] || { echo "FATAL: $ENV_FILE not found — check out your dotfiles first" >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"

MOVES=0 SKIPS=0 WARNS=0

say() { printf '%s\n' "$*"; }
run() { if [ "$APPLY" = 1 ]; then "$@"; else say "        would: $*"; fi; }
running() { pgrep -x "$1" >/dev/null 2>&1; }

# move_dir <label> <src> <dst> [procname]
move_dir() {
	local label="$1" src="$2" dst="$3" proc="${4:-}"
	if [ ! -e "$src" ]; then
		say "[skip] $label — no legacy $(disp "$src")"; SKIPS=$((SKIPS+1)); return 1
	fi
	if [ -e "$dst" ]; then
		say "[skip] $label — target already exists: $(disp "$dst") (reconcile by hand)"; SKIPS=$((SKIPS+1)); return 1
	fi
	if [ -n "$proc" ] && running "$proc"; then
		say "[WARN] $label — '$proc' is running; close it and re-run"; WARNS=$((WARNS+1)); return 1
	fi
	say "[move] $label — $(disp "$src") -> $(disp "$dst")"
	run mkdir -p "$(dirname "$dst")"
	run mv "$src" "$dst"
	MOVES=$((MOVES+1)); return 0
}

disp() { printf '%s' "${1/#$HOME/\~}"; }

# firefox-family native XDG needs the app to be recent enough; skip loudly if old.
ff_major_ok() { # <binary> <min-major>
	command -v "$1" >/dev/null 2>&1 || return 0   # not installed -> nothing to move anyway
	local v; v=$("$1" --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
	[ -n "$v" ] && [ "$v" -ge "$2" ]
}

say "=== xdg-migrate ($([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)) ==="

## --- env-var backed moves (whole dir) ---
move_dir "GnuPG (GNUPGHOME)"        "$HOME/.gnupg"  "${GNUPGHOME:-$XDG_CONFIG_HOME/gnupg}"
move_dir "Docker (DOCKER_CONFIG)"   "$HOME/.docker" "${DOCKER_CONFIG:-$XDG_CONFIG_HOME/docker}"
move_dir "Cargo (CARGO_HOME)"       "$HOME/.cargo"  "${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
move_dir "Gradle (GRADLE_USER_HOME)" "$HOME/.gradle" "${GRADLE_USER_HOME:-$XDG_DATA_HOME/gradle}"
move_dir "Rush (RUSH_GLOBAL_FOLDER)" "$HOME/.rush"  "${RUSH_GLOBAL_FOLDER:-$XDG_DATA_HOME/rush}"
move_dir "distcc (DISTCC_DIR)"      "$HOME/.distcc" "${DISTCC_DIR:-$XDG_CACHE_HOME/distcc}"
move_dir "Copilot CLI (COPILOT_HOME)" "$HOME/.copilot" "${COPILOT_HOME:-$XDG_DATA_HOME/copilot}" copilot

## --- env-var backed moves (sub-dir only; keep the parent's small identity/config) ---
move_dir "Ollama models (OLLAMA_MODELS)" "$HOME/.ollama/models" "${OLLAMA_MODELS:-$XDG_DATA_HOME/ollama/models}" ollama
move_dir "pi agent (PI_CODING_AGENT_DIR)" "$HOME/.pi/agent" "${PI_CODING_AGENT_DIR:-$XDG_DATA_HOME/pi/agent}" pi

## --- Claude Code (running-agent; ~/.claude.json is left as-is) ---
move_dir "Claude Code (CLAUDE_CONFIG_DIR)" "$HOME/.claude" "${CLAUDE_CONFIG_DIR:-$XDG_CONFIG_HOME/claude}" claude

## --- Codex (needs existing dir + launcher symlink fix) ---
if move_dir "Codex CLI (CODEX_HOME)" "$HOME/.codex" "${CODEX_HOME:-$XDG_DATA_HOME/codex}" codex; then
	cdx="${CODEX_HOME:-$XDG_DATA_HOME/codex}"
	run mkdir -p "$cdx"
	cur="$cdx/packages/standalone/current"
	if [ -L "$cur" ]; then
		rel="releases/$(basename "$(readlink "$cur")")"
		say "        fix: relative 'current' -> $rel"
		run ln -sfn "$rel" "$cur"
	fi
	if [ -e "$cdx/packages/standalone/current/bin/codex" ] || [ "$APPLY" = 0 ]; then
		say "        fix: launcher ~/.local/bin/codex"
		run ln -sf "$cdx/packages/standalone/current/bin/codex" "$HOME/.local/bin/codex"
	fi
fi

## --- Maven (localRepository lives in ~/.m2/settings.xml, which holds secrets) ---
mvn_repo_dst="$XDG_DATA_HOME/maven/repository"
mvn_settings="$HOME/.m2/settings.xml"
if [ -d "$HOME/.m2/repository" ] && [ ! -e "$mvn_repo_dst" ]; then
	if [ -f "$mvn_settings" ] && grep -q '<localRepository>.*maven/repository' "$mvn_settings"; then
		move_dir "Maven local repo" "$HOME/.m2/repository" "$mvn_repo_dst"
	else
		say "[WARN] Maven — add this to $(disp "$mvn_settings") (just inside <settings>) then re-run:"
		say '           <localRepository>${user.home}/.local/share/maven/repository</localRepository>'
		WARNS=$((WARNS+1))
	fi
else
	move_dir "Maven local repo" "$HOME/.m2/repository" "$mvn_repo_dst"
fi

## --- native XDG (Firefox 147+, Thunderbird 147+, Zen 1.18.6b+) ---
if ff_major_ok firefox 147; then
	move_dir "Firefox profile" "$HOME/.mozilla" "$XDG_CONFIG_HOME/mozilla" firefox
else
	say "[skip] Firefox — needs >= 147 for XDG (or not installed)"; SKIPS=$((SKIPS+1))
fi
if ff_major_ok thunderbird 147; then
	move_dir "Thunderbird profile" "$HOME/.thunderbird" "$XDG_CONFIG_HOME/thunderbird" thunderbird
else
	say "[skip] Thunderbird — needs >= 147 for XDG (or not installed)"; SKIPS=$((SKIPS+1))
fi
move_dir "Zen profile" "$HOME/.zen" "$XDG_CONFIG_HOME/zen" zen

say ""
say "=== summary: $MOVES move(s), $SKIPS skip(s), $WARNS warning(s) ==="
if [ "$APPLY" = 0 ]; then
	say "dry run — re-run with --apply to perform the moves"
else
	say "done — launch each migrated app to verify; roll back with 'mv <dst> <src>' if a profile is empty"
fi
