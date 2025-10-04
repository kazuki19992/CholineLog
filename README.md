# CholineLog

## ライセンスファイル生成 (Licenses.json)
このプロジェクトではビルド時に `Tools/generate_licenses.sh` を実行して、利用ライブラリのライセンスファイルを走査し `Licenses.json` をアプリバンドルに生成します。`LicensesView` はこの JSON を読み込んで一覧 + 詳細表示します。

### 仕組み
- Xcode ターゲットに既に Shell Script Build Phase が追加済み
- スクリプトは以下ディレクトリ配下を最大 5 階層まで探索し、`LICENSE*`, `NOTICE*`, `COPYING` などを収集
  - `.build/checkouts` (SwiftPM)
  - `Packages/`
  - `Carthage/Checkouts/`
  - CocoaPods 利用時は `PODS_ROOT`
  - プロジェクトルート
- 重複 (name + text) は除外し `{ id, name, text }` の配列 JSON を出力
- 見つからない場合は空配列 `[]` を出力

### 手動生成 (ローカル確認用)
```bash
# ルートディレクトリで
bash Tools/generate_licenses.sh
# 出力例: build/Resources/Licenses.json （Xcode 環境変数が無い場合）
```
Xcode ビルド時は環境変数 `TARGET_BUILD_DIR` / `UNLOCALIZED_RESOURCES_FOLDER_PATH` を用いアプリバンドル内に配置されます。

### JSON フォーマット例
```jsonc
[
  {"id": "abcdef123456", "name": "Alamofire", "text": "MIT License ..."},
  {"id": "...", "name": "SwiftDate", "text": "BSD 3-Clause ..."}
]
```

### カスタマイズ
- 追加で無視したいパスがある場合: `generate_licenses.sh` 内で `found_files` に追加する前に条件を追加
- 出力キーを増やしたい場合: Python 部分で辞書に項目を追加し、`LicenseEntry` の `CodingKeys` を拡張

### トラブルシュート
| 症状 | 対処 |
|------|------|
| 画面に「Licenses.json が見つかりません」 | Build Phase が削除されていないか確認 / スクリプトを手動実行して生成確認 |
| エントリが空 | 依存ライブラリがチェックアウト済みか (`DerivedData`/`.build`) を確認 |
| 文字化け | `generate_licenses.sh` は UTF-8 で読み込み。ライセンスファイルのエンコードを UTF-8 に変更 |

### 注意
このスクリプトはライセンス本文をそのままバンドルします。ストア審査やサイズ最適化で問題となる場合は不要ファイルをフィルタしてください。
