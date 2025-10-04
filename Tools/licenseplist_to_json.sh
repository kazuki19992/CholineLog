#!/usr/bin/env bash
set -euo pipefail
# LicensePlist 生成物 (com.mono0926.LicensePlist.plist / 各 *.txt) から
# 既存 LicensesView が読む Licenses.json ([{id,name,text},...]) を生成する。
# 期待入力ディレクトリ探索優先順:
#  1) build/licenseplist (config の output-path 想定)
#  2) com.mono0926.LicensePlist.Output (デフォルト)
#  3) 明示指定: 環境変数 LICENSE_PLIST_OUTPUT_DIR
# 出力パス: Xcode 環境変数があればバンドル Resources、なければ colinelog/Resources/Licenses.json

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRCROOT=${SRCROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}

# 探索候補
CANDIDATES=()
if [ -n "${LICENSE_PLIST_OUTPUT_DIR:-}" ]; then
  CANDIDATES+=("${LICENSE_PLIST_OUTPUT_DIR}")
fi
CANDIDATES+=(
  "${SRCROOT}/build/licenseplist"
  "${SRCROOT}/com.mono0926.LicensePlist.Output"
)

PLIST_PATH=""
BASE_DIR=""
for d in "${CANDIDATES[@]}"; do
  [ -d "$d" ] || continue
  if [ -f "$d/com.mono0926.LicensePlist.plist" ]; then
    PLIST_PATH="$d/com.mono0926.LicensePlist.plist"
    BASE_DIR="$d"
    break
  fi
  f=$(find "$d" -maxdepth 2 -type f -name 'com.mono0926.LicensePlist.plist' 2>/dev/null | head -n1 || true)
  if [ -n "$f" ]; then
    PLIST_PATH="$f"; BASE_DIR=$(dirname "$f"); break
  fi
done

if [ -z "$PLIST_PATH" ]; then
  echo "[licenseplist_to_json] LicensePlist 出力 plist が見つかりません" >&2
  exit 1
fi

# 出力先決定
if [ -n "${TARGET_BUILD_DIR:-}" ]; then
  OUT_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-Resources}"
else
  OUT_DIR="${SRCROOT}/colinelog/Resources"
fi
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/Licenses.json"
export OUT_FILE

TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON"' EXIT
plutil -convert json -o "$TMP_JSON" "$PLIST_PATH"
export TMP_JSON
export BASE_DIR

python3 - <<'PY'
import json, uuid, os
pl = json.load(open(os.environ['TMP_JSON'],'r',encoding='utf-8'))
base_dir = os.environ.get('BASE_DIR','.')
entries = []
for item in pl.get('PreferenceSpecifiers', []):
    title = item.get('Title')
    if not title:
        continue
    text = ''
    if item.get('FooterText'):
        text = item['FooterText'].strip()
    elif item.get('File'):
        file_path = os.path.join(base_dir, 'com.mono0926.LicensePlist', item['File'])
        if os.path.isfile(file_path):
            with open(file_path,'r',encoding='utf-8',errors='replace') as fh:
                text = fh.read().strip()
    else:
        for k in ('License','Body','Description'):
            if item.get(k):
                text = str(item[k]).strip(); break
    if not text:
        continue
    entries.append({'id': uuid.uuid4().hex, 'name': title, 'text': text})

lower_names = { e['name'].lower() for e in entries }
if 'swift' not in lower_names:
    entries.append({'id': uuid.uuid4().hex,'name':'Swift','text':'Swift Apache 2.0 License\nhttps://github.com/swiftlang/swift/blob/main/LICENSE.txt'})

out_file = os.environ['OUT_FILE']
with open(out_file,'w',encoding='utf-8') as w:
    json.dump(entries,w,ensure_ascii=False,indent=2)
print(f"Wrote {len(entries)} entries -> {out_file}")
PY

echo "[licenseplist_to_json] 完了: $OUT_FILE"
