-- 管理画面にユーザーの最終ログイン日時を表示するための列。
-- クライアント側は列が無い場合でも動くようフォールバックを実装済み。
alter table public.user_app_state add column if not exists last_login_at timestamptz;
alter table public.thai_user_app_state add column if not exists last_login_at timestamptz;
