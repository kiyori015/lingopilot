# Supabase運用設計

## 目的

このアプリは一般公開せず、管理者が許可したユーザーだけが数か月から半年程度利用する前提で運用する。

## 保存方針

- 正の保存先: Supabase Postgres
- 一時保存先: ブラウザlocalStorage
- コードと仕様の管理: GitHub

localStorageは端末を変えると引き継げないため、学習記録の正式な保存先にはしない。通信不良時の一時退避として使い、ログイン後にSupabaseへ同期する。

## 保存する学習記録

### 日別記録
- 学習日
- 学習時間
- 解答数
- 正答数
- 完了章数

この記録から、今日の学習時間、累計学習時間、連続学習日数、直近7日サマリー、月間カレンダーを表示する。

### 進捗記録
- 最後に開いていた章
- 章ごとの回答状況
- 単語カードの自己採点
- アウトプット練習の進捗
- リマインド設定
- 質問メモ

この記録から、続きから学習、得意分野、苦手分野、補講導線を表示する。

## ログイン方針

### 推奨

1. 管理者が管理画面でユーザーのメールアドレスを登録する。
2. 登録順に `01`、`02`、`03`...の登録番号を発行する。
3. 管理者は登録番号、メールアドレス、共通QRコードをユーザーに送る。
4. ユーザーはQRコードから初回アクセスする。
5. 登録番号とメールアドレスを入力してログインする。
6. 2回目以降はブラウザに残るSupabase Authセッションを使い、再ログインの手間を減らす。
7. スマホではホーム画面に追加したアプリアイコンから開く。

### 理由

- パスワード配布が不要になる。
- 管理画面で登録していないメールアドレスと登録番号ではログインできない。
- 端末紛失や共有端末ではログアウトすればよい。
- 半年程度のお試し運用として管理しやすい。

## 権限方針

- 一般ユーザー: 自分のプロフィール、進捗、日別記録だけ閲覧・更新できる。
- 管理者: 全ユーザーのプロフィール、進捗、日別記録を閲覧できる。
- 未ログインユーザー: 学習記録テーブルにはアクセスできない。

Supabaseの公開スキーマに作るテーブルはRLSを有効にする。

## 管理者作業

- 管理画面から利用者メールアドレスを追加する。
- 必要に応じて `profiles.student_id` と `profiles.display_name` を編集する。
- 管理者アカウントは `profiles.role = 'admin'` にする。
- 利用終了者は `profiles.status = 'inactive'` にするか、Supabase Auth側でユーザーを削除する。

## 初回セットアップ手順

1. Supabase DashboardのSQL Editorで `supabase/migrations/202605310001_learning_records.sql` を実行する。
2. Supabase DashboardのSQL Editorで `supabase/migrations/202606200001_registration_number_login.sql` を実行する。
3. `lingopilot-auth` Edge Functionをデプロイする。
4. Edge Functionに `SUPABASE_SERVICE_ROLE_KEY`、`LINGOPILOT_LOGIN_PEPPER`、`LINGOPILOT_APP_URL` を設定する。
5. Supabase Authで管理者用メールアドレスを登録する。
6. SQL Editorで管理者のプロフィールを更新する。

```sql
update public.profiles
set role = 'admin'
where email = '管理者のメールアドレス';
```

7. 管理画面でテスト用メールアドレスを登録する。
8. 発行された登録番号とメールアドレスでログインできるか確認する。

## 現時点の注意点

- 管理画面内のユーザー追加フォームは、`lingopilot-auth` Edge Functionのデプロイ後に動作する。
- 実際のログイン許可は `profiles.registration_number` とメールアドレスの組み合わせで管理する。
- メール本文は管理画面で作成するが、送信自体はメールアプリまたは別サービスで行う。
- マイグレーション適用前は、学習記録はlocalStorageに一時保存される。

## 参考

- Supabase Passwordless email login: https://supabase.com/docs/guides/auth/auth-email-passwordless
- Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
