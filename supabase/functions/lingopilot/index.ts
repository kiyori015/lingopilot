import "@supabase/functions-js/edge-runtime.d.ts";

const createHtmlHeaders = () => {
  const headers = new Headers();
  headers.set("Content-Type", "text/html; charset=utf-8");
  headers.set("Cache-Control", "public, max-age=300");
  return headers;
};

const createAssetHeaders = (contentType: string) => {
  const headers = new Headers();
  headers.set("Content-Type", contentType);
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
  const assetMap: Record<string, { fileName: string; contentType: string }> = {
    "/manifest.webmanifest": { fileName: "manifest.webmanifest", contentType: "application/manifest+json; charset=utf-8" },
    "/sw.js": { fileName: "sw.js", contentType: "application/javascript; charset=utf-8" },
    "/assets/lingopilot-icon.svg": { fileName: "assets/lingopilot-icon.svg", contentType: "image/svg+xml; charset=utf-8" },
    "/assets/lingopilot-app-qr.svg": { fileName: "assets/lingopilot-app-qr.svg", contentType: "image/svg+xml; charset=utf-8" },
    "/assets/lingopilot-app-qr.png": { fileName: "assets/lingopilot-app-qr.png", contentType: "image/png" }
  };
  const matchedAsset = Object.entries(assetMap).find(([suffix]) => pathname.endsWith(suffix));
  if (matchedAsset) {
    const [, asset] = matchedAsset;
    const body = asset.contentType.startsWith("image/")
      ? await Deno.readFile(new URL(asset.fileName, import.meta.url))
      : await Deno.readTextFile(new URL(asset.fileName, import.meta.url));
    return new Response(body, { headers: createAssetHeaders(asset.contentType) });
  }

  const fileName = pathname.endsWith("/thai") || pathname.endsWith("/thai.html")
    ? "thai.html"
    : pathname.endsWith("/lingopilot") || pathname.endsWith("/index.html") || pathname === ""
    ? "index.html"
    : "";

  if (!fileName) {
    return new Response(notFoundHtml, { status: 404, headers: createHtmlHeaders() });
  }

  const html = await Deno.readTextFile(new URL(fileName, import.meta.url));
  return new Response(html, { headers: createHtmlHeaders() });
});
