import { createClient } from "@supabase/supabase-js";

type RequestBody = {
  action?: "register" | "login";
  email?: string;
  registrationNumber?: string;
  appUrl?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8"
    }
  });

const normalizeEmail = (value = "") => value.trim().toLowerCase();
const normalizeRegistrationNumber = (value = "") => value.replace(/\D/g, "").padStart(2, "0");
const isEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
const isRegistrationNumber = (value: string) => /^[0-9]{2,4}$/.test(value);

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const loginPepper = Deno.env.get("LINGOPILOT_LOGIN_PEPPER") || serviceRoleKey;
const defaultAppUrl = Deno.env.get("LINGOPILOT_APP_URL") || "https://kiyori015.github.io/lingopilot/";

const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

const anonClient = createClient(supabaseUrl, anonKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

const toBase64Url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");

const derivePassword = async (email: string, registrationNumber: string) => {
  const payload = `${loginPepper}:${email}:${registrationNumber}:lingopilot-registration-login`;
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(payload));
  return `LP_${registrationNumber}_${toBase64Url(new Uint8Array(hash))}`;
};

const buildInviteMail = (email: string, registrationNumber: string, appUrl: string) => {
  const subject = "韓国語ラボのログイン案内";
  const body = [
    "韓国語ラボの利用登録が完了しました。",
    "",
    `登録番号: ${registrationNumber}`,
    `メールアドレス: ${email}`,
    `アプリURL: ${appUrl}`,
    "",
    "スマホの場合はQRコードを読み込んで開いてください。",
    "パソコンの場合は上のURLをブラウザで開いてください。",
    "",
    "ログイン画面で登録番号とメールアドレスを入力すると、マイページが開きます。"
  ].join("\n");
  return {
    subject,
    body,
    mailtoUrl: `mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
  };
};

const requireAdmin = async (req: Request) => {
  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return false;

  const { data: userData, error: userError } = await serviceClient.auth.getUser(token);
  if (userError || !userData.user) return false;

  const { data: profile, error: profileError } = await serviceClient
    .from("profiles")
    .select("role,status")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (profileError) return false;

  return profile?.role === "admin" && profile?.status === "active";
};

const findAuthUserByEmail = async (email: string) => {
  for (let page = 1; page <= 10; page += 1) {
    const { data, error } = await serviceClient.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    const found = data.users.find((user) => normalizeEmail(user.email || "") === email);
    if (found) return found;
    if (data.users.length < 1000) return null;
  }
  return null;
};

const registerUser = async (req: Request, body: RequestBody) => {
  if (!(await requireAdmin(req))) {
    return json({ error: "admin-required" }, 403);
  }

  const email = normalizeEmail(body.email || "");
  const appUrl = body.appUrl || defaultAppUrl;
  if (!isEmail(email)) {
    return json({ error: "invalid-email" }, 400);
  }

  const { data: existingProfile, error: existingProfileError } = await serviceClient
    .from("profiles")
    .select("id,email,registration_number,registered_order")
    .eq("email", email)
    .maybeSingle();
  if (existingProfileError) throw existingProfileError;

  let registrationNumber = existingProfile?.registration_number || "";
  let registeredOrder = existingProfile?.registered_order || null;
  if (!registrationNumber) {
    const { data: reserved, error: reserveError } = await serviceClient
      .rpc("reserve_registration_number")
      .single();
    if (reserveError) throw reserveError;
    registrationNumber = reserved.registration_number;
    registeredOrder = reserved.registered_order;
  }

  const password = await derivePassword(email, registrationNumber);
  const metadata = {
    student_id: registrationNumber,
    registration_number: registrationNumber,
    registered_order: String(registeredOrder || Number(registrationNumber))
  };

  let authUser = existingProfile?.id ? null : await findAuthUserByEmail(email);
  if (!authUser && !existingProfile?.id) {
    const { data: created, error: createError } = await serviceClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: metadata
    });
    if (createError) throw createError;
    authUser = created.user;
  }

  const userId = existingProfile?.id || authUser?.id;
  if (!userId) {
    return json({ error: "user-not-found" }, 500);
  }

  const { error: updateAuthError } = await serviceClient.auth.admin.updateUserById(userId, {
    email,
    password,
    email_confirm: true,
    user_metadata: metadata
  });
  if (updateAuthError) throw updateAuthError;

  const { error: profileError } = await serviceClient
    .from("profiles")
    .upsert({
      id: userId,
      email,
      student_id: registrationNumber,
      registration_number: registrationNumber,
      registered_order: registeredOrder || Number(registrationNumber),
      registered_at: new Date().toISOString(),
      role: "student",
      status: "active"
    }, { onConflict: "id" });
  if (profileError) throw profileError;

  const { error: appStateError } = await serviceClient
    .from("user_app_state")
    .upsert({ user_id: userId }, { onConflict: "user_id" });
  if (appStateError) throw appStateError;

  return json({
    email,
    registrationNumber,
    appUrl,
    mail: buildInviteMail(email, registrationNumber, appUrl)
  });
};

const loginUser = async (body: RequestBody) => {
  const email = normalizeEmail(body.email || "");
  const registrationNumber = normalizeRegistrationNumber(body.registrationNumber || "");
  if (!isEmail(email) || !isRegistrationNumber(registrationNumber)) {
    return json({ error: "invalid-login" }, 400);
  }

  const { data: profile, error: profileError } = await serviceClient
    .from("profiles")
    .select("id,email,registration_number,status")
    .eq("email", email)
    .eq("registration_number", registrationNumber)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile || profile.status !== "active") {
    return json({ error: "invalid-login" }, 401);
  }

  const password = await derivePassword(email, registrationNumber);
  const { data, error } = await anonClient.auth.signInWithPassword({ email, password });
  if (error || !data.session) {
    const { error: updateError } = await serviceClient.auth.admin.updateUserById(profile.id, {
      password,
      email_confirm: true,
      user_metadata: {
        student_id: registrationNumber,
        registration_number: registrationNumber
      }
    });
    if (updateError) throw updateError;
    const retry = await anonClient.auth.signInWithPassword({ email, password });
    if (retry.error || !retry.data.session) return json({ error: "invalid-login" }, 401);
    return json({ session: retry.data.session, registrationNumber });
  }

  return json({ session: data.session, registrationNumber });
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method-not-allowed" }, 405);
  }

  try {
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !loginPepper) {
      return json({ error: "missing-env" }, 500);
    }
    const body = await req.json() as RequestBody;
    if (body.action === "register") return await registerUser(req, body);
    if (body.action === "login") return await loginUser(body);
    return json({ error: "unknown-action" }, 400);
  } catch (error) {
    console.error(error);
    return json({ error: "server-error" }, 500);
  }
});
