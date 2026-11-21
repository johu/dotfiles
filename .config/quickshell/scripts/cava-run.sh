#!/bin/sh
# Runs cava for the bar pill and the media view: cava-run.sh CONFIG
# Tries the input methods in CAVA_METHODS (default: pipewire, then pulse) so a cava built without PipeWire support
# (Gentoo: USE=-pipewire) or a failing capture still gives a visualizer. A run that ends within 3 s counts as failed
# and the next method is tried; cava's own error output goes to stderr (the quickshell log, prefixed "cava:").
cfg=$1
[ -r "$cfg" ] || { echo "cava-run: cannot read config '$cfg'" >&2; exit 2; }
tmp=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/cava-run.XXXXXX") || exit 2
pid=""
trap 'kill $pid 2>/dev/null; rm -f "$tmp"; exit 0' TERM INT HUP
for m in ${CAVA_METHODS:-pipewire pulse}; do
  # only the [input] method: [output] has its own "method = raw"
  awk -v m="$m" '/^\[/ {sec=$0} sec=="[input]" && /^method[ ]*=/ {print "method = " m; next} {print}' "$cfg" > "$tmp"
  start=$(date +%s)
  cava -p "$tmp" &
  pid=$!
  wait $pid
  rc=$?
  [ $(( $(date +%s) - start )) -ge 3 ] && { rm -f "$tmp"; exit $rc; }
  echo "cava-run: method '$m' failed (exit $rc), next" >&2
done
rm -f "$tmp"
echo "cava-run: no input method worked" >&2
exit 1
