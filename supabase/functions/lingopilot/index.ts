import "@supabase/functions-js/edge-runtime.d.ts";

const createHtmlHeaders = () => {
  const headers = new Headers();
  headers.set("Content-Type", "text/html; charset=utf-8");
  headers.set("Cache-Control", "public, max-age=300");
  return headers;
};

const notFoundHtml = `<!doctype html>
<html lang="ja">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Lingopilot</title>
  </head>
  <body>
    <h1>404</h1>
    <p>ページが見つかりません。</p>
    <p><a href="/functions/v1/lingopilot">トップへ戻る</a></p>
  </body>
</html>`;

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const pathname = url.pathname.replace(/\/+$/, "");
  const fileName = pathname.endsWith("/thai") || pathname.endsWith("/thai.html")
    ? "thai.html"
    : pathname.endsWith("/lingopilot") || pathname === ""
    ? "index.html"
    : "";

  if (!fileName) {
    return new Response(notFoundHtml, { status: 404, headers: createHtmlHeaders() });
  }

  const html = await Deno.readTextFile(new URL(fileName, import.meta.url));
  return new Response(html, { headers: createHtmlHeaders() });
});
