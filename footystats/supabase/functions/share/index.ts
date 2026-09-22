import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const APP_ORIGIN = "https://app.ballonetwork.com";
const FALLBACK_IMAGE = `${APP_ORIGIN}/icons/Icon-512.png`;
const DESCRIPTION = "Now you know.";
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function previewHtml(opts: {
  title: string;
  image: string;
  appLink: string;
  playLink: string;
  redirect: boolean;
}): string {
  const safeTitle = escapeHtml(opts.title);
  const safeImage = escapeHtml(opts.image);
  const safeLink = escapeHtml(opts.appLink);
  const redirect = opts.redirect
    ? `<script>location.replace(${JSON.stringify(opts.playLink)});</script>`
    : "";
  const body = opts.redirect
    ? `<p><a href="${escapeHtml(opts.playLink)}" style="color:#fff">Watch on Ballo</a></p>`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${safeTitle}</title>
  <meta name="description" content="${DESCRIPTION}">
  <meta property="og:site_name" content="Ballo">
  <meta property="og:title" content="${safeTitle}">
  <meta property="og:description" content="${DESCRIPTION}">
  <meta property="og:type" content="video.other">
  <meta property="og:url" content="${safeLink}">
  <meta property="og:image" content="${safeImage}">
  <meta property="og:image:secure_url" content="${safeImage}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${safeTitle}">
  <meta name="twitter:description" content="${DESCRIPTION}">
  <meta name="twitter:image" content="${safeImage}">
  <link rel="canonical" href="${safeLink}">
  <link rel="image_src" href="${safeImage}">
  ${redirect}
</head>
<body style="background:#000;color:#fff;font-family:sans-serif">
  ${body}
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const url = new URL(req.url);
  const videoId = (url.searchParams.get("v") ?? url.searchParams.get("video") ?? "")
    .trim();
  const wantJson = url.searchParams.get("format") === "json" ||
    (req.headers.get("accept") ?? "").includes("application/json");

  if (!UUID.test(videoId)) {
    if (wantJson) {
      return Response.json({ error: "invalid_id" }, { status: 400, headers: cors });
    }
    return Response.redirect(`${APP_ORIGIN}/`, 302);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  );

  const { data: video } = await supabase
    .from("videos")
    .select("id, video_url, thumbnail_url, match_id")
    .eq("id", videoId)
    .maybeSingle();

  let title = "Highlight on Ballo";
  const thumbnail = (video?.thumbnail_url as string | undefined)?.trim() ||
    FALLBACK_IMAGE;
  const videoUrl = (video?.video_url as string | undefined)?.trim() ?? "";
  const matchId = video?.match_id as string | undefined;

  if (matchId) {
    const { data: match } = await supabase
      .from("matches")
      .select("teamA:teams!teamA(short_form), teamB:teams!teamB(short_form)")
      .eq("id", matchId)
      .maybeSingle();
    const teamA = (match?.teamA as { short_form?: string } | null)?.short_form;
    const teamB = (match?.teamB as { short_form?: string } | null)?.short_form;
    if (teamA && teamB) title = `${teamA} vs ${teamB} — Ballo`;
  }

  const appLink = `${APP_ORIGIN}/?v=${encodeURIComponent(videoId)}`;
  const playLink = `${appLink}&play=1`;

  if (wantJson) {
    return Response.json(
      {
        id: videoId,
        title,
        description: DESCRIPTION,
        thumbnail_url: thumbnail,
        video_url: videoUrl,
        app_url: appLink,
      },
      { headers: cors },
    );
  }

  const html = previewHtml({
    title,
    image: thumbnail,
    appLink,
    playLink,
    redirect: true,
  });

  return new Response(html, {
    headers: {
      ...cors,
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
    },
  });
});
