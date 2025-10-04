#!/usr/bin/env bash
set -euo pipefail

# Generate Licenses.json into the app bundle resources during build.
# This script scans common locations for license/notice files and writes
# a JSON array of { name, text } to the app resources directory.

SRCROOT=${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}
OUT_DIR=${TARGET_BUILD_DIR:-"$SRCROOT/build"}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-"Resources"}
OUT_FILE="$OUT_DIR/Licenses.json"

mkdir -p "$OUT_DIR"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

# Directories to scan
paths=(
  "$SRCROOT/.build/checkouts"
  "$SRCROOT/Packages"
  "$SRCROOT/Carthage/Checkouts"
)
if [ -n "${PODS_ROOT:-}" ]; then paths+=("${PODS_ROOT}"); fi
paths+=("$SRCROOT")

# Filename patterns to look for
shopt -s nullglob
candidates=("LICENSE" "LICENSE.txt" "LICENSE.md" "COPYING" "NOTICE" "NOTICE.txt")

# Find license-like files
found_files=()
for p in "${paths[@]}"; do
  [ -d "$p" ] || continue
  # quick direct matches
  for cand in "${candidates[@]}"; do
    while IFS= read -r -d $'\0' f; do
      found_files+=("$f")
    done < <(find "$p" -maxdepth 5 -type f \( -iname "$cand" -o -iname "${cand,,}" \) -print0 2>/dev/null)
  done
  # generic search for 'license' or 'notice' in filename
  while IFS= read -r -d $'\0' f; do
    found_files+=("$f")
  done < <(find "$p" -maxdepth 5 -type f \( -iname "*license*" -o -iname "*notice*" \) -print0 2>/dev/null)
done

# Normalize and dedupe by path
IFS=$'\n' read -r -d '' -a found_files < <(printf '%s\0' "${found_files[@]}" | xargs -0 -n1 printf '%s\0' | sort -z -u && printf '\0') || true

# Emit tab-separated (name \t file)
for f in "${found_files[@]}"; do
  [ -f "$f" ] || continue
  # choose display name: parent directory name or file basename
  name=$(basename "$(dirname "$f")")
  echo -e "${name}\t${f}" >> "$tmpfile"
done

# If nothing found, fallback to app bundle's Licenses.json or LICENSES.txt
if [ ! -s "$tmpfile" ]; then
  if [ -f "$SRCROOT/colinelog/Resources/Licenses.json" ]; then
    cp "$SRCROOT/colinelog/Resources/Licenses.json" "$OUT_FILE"
    echo "Copied existing Licenses.json to $OUT_FILE"
    exit 0
  fi
  if [ -f "$SRCROOT/colinelog/Resources/LICENSES.txt" ]; then
    # split by marker
    python3 - <<PY > "$OUT_FILE"
import json
parts = open('$SRCROOT/colinelog/Resources/LICENSES.txt', encoding='utf-8').read().split('\n----\n')
out = [{'id': __import__('uuid').uuid4().hex, 'name': f'ライセンス {i+1}', 'text': p} for i,p in enumerate(parts)]
json.dump(out, open('$OUT_FILE','w',encoding='utf-8'), ensure_ascii=False, indent=2)
PY
    echo "Generated $OUT_FILE from LICENSES.txt"
    exit 0
  fi
  # Nothing to do
  echo "No license files found; leaving $OUT_FILE empty" >&2
  printf '[]' > "$OUT_FILE"
  exit 0
fi

# Build JSON using python to handle encoding properly
python3 - <<PY > "$OUT_FILE"
import json, uuid
entries = []
seen = set()
with open('$tmpfile', 'r', encoding='utf-8') as fh:
    for line in fh:
        line = line.rstrip('\n')
        if not line: continue
        name, path = line.split('\t', 1)
        try:
            text = open(path, 'r', encoding='utf-8', errors='replace').read().strip()
        except Exception:
            continue
        key = (name, text)
        if key in seen: continue
        seen.add(key)
        entries.append({'id': uuid.uuid4().hex, 'name': name, 'text': text})
json.dump(entries, open('$OUT_FILE','w',encoding='utf-8'), ensure_ascii=False, indent=2)
PY

echo "Wrote licenses to $OUT_FILE"
exit 0
