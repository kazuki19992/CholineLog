rm colinelog/Resources/Licenses.json
bash Tools/generate_licenses.sh
cat colinelog/Resources/Licenses.json#!/usr/bin/env bash
set -euo pipefail

# Generate Licenses.json into the app bundle resources during build.
# This script scans common locations for license/notice files and writes
# a JSON array of { id, name, text } to the app resources directory.

SRCROOT=${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}

if [ -n "${TARGET_BUILD_DIR:-}" ]; then
  OUT_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-Resources}"
else
  OUT_DIR="${SRCROOT}/colinelog/Resources"
fi
OUT_FILE="${OUT_DIR}/Licenses.json"
export OUT_FILE
mkdir -p "${OUT_DIR}"

SOURCE_EXT_RE='^(swift|m|mm|h|hpp|c|cc|cpp|py|rb|js|ts|tsx|cs|java|kt|go|rs|gradle|podspec|sh|bash|zsh|fish|yml|yaml|json|plist|xcodeproj|xcworkspace)$'

is_source_like() {
  local f="$1"; local base="${f##*/}"; local name_no_ext="$base"; local ext="";
  if [[ "$base" == *.* ]]; then ext="${base##*.}"; name_no_ext="${base%.*}"; fi
  local lower_name=$(printf '%s' "$name_no_ext" | tr 'A-Z' 'a-z')
  local lower_ext=$(printf '%s' "$ext" | tr 'A-Z' 'a-z')
  case "$lower_name" in license|licenses|copying|notice) return 1 ;; esac
  if [[ -n "$lower_ext" && "$lower_ext" =~ $SOURCE_EXT_RE ]]; then return 0; fi
  return 1
}

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

paths=("$SRCROOT/.build/checkouts" "$SRCROOT/Packages" "$SRCROOT/Carthage/Checkouts")
if [ -n "${PODS_ROOT:-}" ]; then paths+=("${PODS_ROOT}"); fi
paths+=("$SRCROOT")

shopt -s nullglob
candidates=("LICENSE" "LICENSE.txt" "LICENSE.md" "COPYING" "NOTICE" "NOTICE.txt")
found_files=()
for p in "${paths[@]}"; do
  [ -d "$p" ] || continue
  for cand in "${candidates[@]}"; do
    while IFS= read -r -d $'\0' f; do found_files+=("$f"); done < <(find "$p" -maxdepth 5 -type f -iname "$cand" -print0 2>/dev/null)
  done
  while IFS= read -r -d $'\0' f; do found_files+=("$f"); done < <(find "$p" -maxdepth 5 -type f \( -iname "*license*" -o -iname "*notice*" \) -print0 2>/dev/null)
done

for f in "${found_files[@]}"; do
  [ -f "$f" ] || continue
  if [[ "$f" == "$SRCROOT/Tools"* ]] || [[ "$f" == *.sh ]]; then continue; fi
  if is_source_like "$f"; then if [ $? -eq 0 ]; then continue; fi; fi
  name=$(basename "$(dirname "$f")")
  echo -e "${name}\t${f}" >> "$tmpfile"
done

python3 - <<PY
import json, uuid, os
OUT_FILE = r"${OUT_FILE}"
TMP_PATH = r"${tmpfile}"
entries = []
seen = set()
if os.path.isfile(TMP_PATH):
    with open(TMP_PATH,'r',encoding='utf-8') as fh:
        for line in fh:
            line = line.rstrip('\n')
            if not line or '\t' not in line: continue
            name, path = line.split('\t',1)
            try:
                with open(path,'r',encoding='utf-8',errors='replace') as f:
                    text = f.read().strip()
            except Exception:
                continue
            key=(name,text)
            if key in seen: continue
            seen.add(key)
            entries.append({'id': uuid.uuid4().hex,'name': name,'text': text})
# Inject Swift / SwiftUI if absent
names = {e['name'].lower() for e in entries}
if 'swift' not in names:
    entries.append({'id': uuid.uuid4().hex,'name': 'Swift','text': """Swift
Copyright (c) Apple Inc. and the Swift project authors.
Licensed under the Apache License, Version 2.0:
http://www.apache.org/licenses/LICENSE-2.0
Distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS.
Full text: https://github.com/swiftlang/swift/blob/main/LICENSE.txt"""})
if 'swiftui' not in names:
    entries.append({'id': uuid.uuid4().hex,'name': 'SwiftUI','text': """SwiftUI は Apple 提供の Apple Platform SDK の一部で、個別 OSS ライセンス本文は提供されません。
利用条件は Apple Developer Program License Agreement / SDK License に従います。
https://developer.apple.com/terms/
https://www.apple.com/legal/sla/
本アプリは SwiftUI フレームワークを利用しています。"""})
with open(OUT_FILE,'w',encoding='utf-8') as w:
    json.dump(entries,w,ensure_ascii=False,indent=2)
PY

echo "Wrote licenses (Swift / SwiftUI included) to $OUT_FILE"
exit 0
