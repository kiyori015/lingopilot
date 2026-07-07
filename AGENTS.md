# Repository Guidelines

言語学習アプリ「lingopilot」（卒業研究）。韓国語版・タイ語版の2つの単一HTMLアプリ。

**必読**: 直近の大規模改修（2026年7月）の内容・設計判断・運用手順は
`docs/claude-handoff-2026-07.md` にまとまっている。発表・論文作成や機能改修の前に必ず読むこと。

## プロジェクト構成

- `src/index.html` — 韓国語版アプリ（HTML+CSS+JSすべて1ファイル、約8,700行）
- `src/thai.html` — タイ語版アプリ（同、約10,900行）
- `src/sw.js` / `src/manifest.webmanifest` — PWA（SWはネットワーク優先キャッシュ）
- `supabase/migrations/` — DBマイグレーション（適用は `scripts/apply-migrations.ps1`）
- `supabase/functions/lingopilot-auth/` — 登録番号ログイン用Edge Function
- `docs/` — 仕様・運用手順・引き継ぎ書
- `scripts/` — PowerShell運用スクリプト（pwsh 7 で実行）

## 開発・確認コマンド

- ローカル確認: `python -m http.server 4173` → `http://localhost:4173/src/index.html`
- 公開: `git push origin main`（GitHub Actions が `src/` を GitHub Pages に自動デプロイ）
- DBマイグレーション: `pwsh ./scripts/apply-migrations.ps1`（接続はap-south-1プーラー経由。直結ホストはIPv6のみで不可）

## コーディング規約

- バニラJS、インデント2スペース、`const`+アロー関数中心。既存コードの書き方に合わせる
- **修正は必ず韓国語版・タイ語版の両方に適用する**（ロジックが大部分重複。関数名が微妙に違う点に注意:
  韓 `speakSentence`/`chapter.quizSets` ⇔ タイ `speakText`/`state.exerciseSets` など）
- UI文言は日本語。正誤表示は色+記号+文言の3重表現を維持する
- 学習記録に影響する変更では、localStorage（端末）と Supabase（サーバー）の両方の整合を確認する

## テスト

- 自動テストはなし。ブラウザでの手動確認+コンソールでの検証を行う
- ログインを通さずUIを確認する場合（コンソールで実行、終了後 `zztest` を含むlocalStorageキーを削除）:
  `remoteSyncEnabled = false; applyAuthenticatedState("zztest", false); signedInAuthUserId = "";`
- 変更後はインラインJSの構文チェックを推奨（`<script>` 内容を `new Function()` に通す）

## コミット・PR

- `type(scope): summary` 形式（例: `feat(learning): ...`、`fix(results): ...`）。本文に日本語で変更理由を書く
- push 前に `git status` / `git diff --stat` で予期しない変更（他ツールの並行作業）がないか確認する
- **ClaudeとCodexに同じ作業を同時に依頼しない**（2026/07/04に同時書き込みが発生した実績あり）

## 秘密情報

- `.env.local`（DBパスワード・サービスロールキー・ログインペッパー）はコミット禁止
- Supabaseプロジェクト: `ieakvpwzhihqttcxegti`（リージョン ap-south-1）
