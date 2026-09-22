import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * Content moderation via OpenAI Moderation API (omni-moderation-latest).
 * Secret OPENAI_API_KEY must be set in Supabase Edge Function secrets.
 *
 * Body:
 * {
 *   kind: "text" | "image" | "video_frames",
 *   text?: string,
 *   imageBase64?: string,          // raw base64 or data URL
 *   framesBase64?: string[],       // up to 15 JPEG frames
 *   sportsContext?: boolean,       // lower violence sensitivity for football clips
 *   contentRef?: string,
 *   contentType?: "video" | "image" | "text"
 * }
 */

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Decision = "allow" | "review" | "reject";

const HARD_REJECT = 0.85;
const REVIEW_FLOOR = 0.55;
const VIOLENCE_HARD = 0.92;
const VIOLENCE_REVIEW = 0.70;
const VIOLENCE_SPORTS_HARD = 0.97;
const VIOLENCE_SPORTS_REVIEW = 0.88;

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: cors });
}

function toDataUrl(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.startsWith("data:")) return trimmed;
  return `data:image/jpeg;base64,${trimmed}`;
}

function maxScore(
  scores: Record<string, number>,
  keys: string[],
): number {
  let m = 0;
  for (const k of keys) {
    const v = scores[k];
    if (typeof v === "number" && v > m) m = v;
  }
  return m;
}

function decideFromScores(
  scores: Record<string, number>,
  sportsContext: boolean,
): { decision: Decision; reasons: string[] } {
  const reasons: string[] = [];

  const sexual = maxScore(scores, ["sexual", "sexual/minors"]);
  const hate = maxScore(scores, ["hate", "hate/threatening"]);
  const harassment = maxScore(scores, ["harassment", "harassment/threatening"]);
  const selfHarm = maxScore(scores, [
    "self-harm",
    "self-harm/intent",
    "self-harm/instructions",
  ]);
  const illicit = maxScore(scores, ["illicit", "illicit/violent"]);
  const violence = maxScore(scores, ["violence", "violence/graphic"]);

  const hardRejectKeys: Array<[string, number]> = [
    ["sexual", sexual],
    ["hate", hate],
    ["harassment", harassment],
    ["self-harm", selfHarm],
    ["illicit", illicit],
  ];

  for (const [label, score] of hardRejectKeys) {
    if (score >= HARD_REJECT) {
      reasons.push(`${label}:${score.toFixed(3)}`);
      return { decision: "reject", reasons };
    }
  }

  const vHard = sportsContext ? VIOLENCE_SPORTS_HARD : VIOLENCE_HARD;
  const vReview = sportsContext ? VIOLENCE_SPORTS_REVIEW : VIOLENCE_REVIEW;
  if (violence >= vHard) {
    reasons.push(`violence:${violence.toFixed(3)}`);
    return { decision: "reject", reasons };
  }

  for (const [label, score] of hardRejectKeys) {
    if (score >= REVIEW_FLOOR) {
      reasons.push(`${label}:${score.toFixed(3)}`);
      return { decision: "review", reasons };
    }
  }
  if (violence >= vReview) {
    reasons.push(`violence:${violence.toFixed(3)}`);
    return { decision: "review", reasons };
  }

  return { decision: "allow", reasons };
}

async function callOpenAI(
  apiKey: string,
  input: unknown[],
): Promise<{
  flagged: boolean;
  category_scores: Record<string, number>;
  categories: Record<string, boolean>;
}> {
  const res = await fetch("https://api.openai.com/v1/moderations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "omni-moderation-latest",
      input,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`OpenAI moderation failed (${res.status}): ${body}`);
  }

  const payload = await res.json();
  const result = payload?.results?.[0];
  if (!result) throw new Error("Empty moderation response");

  return {
    flagged: !!result.flagged,
    category_scores: result.category_scores ?? {},
    categories: result.categories ?? {},
  };
}

function mergeScores(
  a: Record<string, number>,
  b: Record<string, number>,
): Record<string, number> {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) {
    if (typeof v !== "number") continue;
    out[k] = Math.max(out[k] ?? 0, v);
  }
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return json({ error: "OPENAI_API_KEY not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.toLowerCase().startsWith("bearer ")) {
      return json({ error: "Missing Authorization" }, 401);
    }
    const accessToken = authHeader.slice(7).trim();
    if (!accessToken) {
      return json({ error: "Missing Authorization" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY")!;
    // Pass the JWT explicitly — Deno clients have no persisted session, so
    // getUser() without a token often returns Unauthorized for valid signups.
    const userClient = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser(accessToken);
    if (userError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json();
    const kind = String(body.kind ?? "");
    const sportsContext = body.sportsContext === true;
    const contentRef = typeof body.contentRef === "string"
      ? body.contentRef
      : null;
    const contentType = (body.contentType as string | undefined) ??
      (kind === "video_frames"
        ? "video"
        : kind === "image"
        ? "image"
        : "text");

    let scores: Record<string, number> = {};
    let flagged = false;

    if (kind === "text") {
      const text = String(body.text ?? "").trim();
      if (!text) return json({ error: "text required" }, 400);
      if (text.length > 2000) {
        return json({ error: "text too long" }, 400);
      }
      const result = await callOpenAI(apiKey, [
        { type: "text", text },
      ]);
      scores = result.category_scores;
      flagged = result.flagged;
    } else if (kind === "image") {
      const raw = String(body.imageBase64 ?? "").trim();
      if (!raw) return json({ error: "imageBase64 required" }, 400);
      const result = await callOpenAI(apiKey, [
        {
          type: "image_url",
          image_url: { url: toDataUrl(raw) },
        },
      ]);
      scores = result.category_scores;
      flagged = result.flagged;
    } else if (kind === "video_frames") {
      const frames = Array.isArray(body.framesBase64)
        ? body.framesBase64.map((f: unknown) => String(f))
        : [];
      if (frames.length === 0) {
        return json({ error: "framesBase64 required" }, 400);
      }
      if (frames.length > 15) {
        return json({ error: "max 15 frames" }, 400);
      }

      // Batch frames in groups of 5 to stay under payload limits.
      for (let i = 0; i < frames.length; i += 5) {
        const chunk = frames.slice(i, i + 5);
        const input = chunk.map((f: string) => ({
          type: "image_url",
          image_url: { url: toDataUrl(f) },
        }));
        const result = await callOpenAI(apiKey, input);
        scores = mergeScores(scores, result.category_scores);
        flagged = flagged || result.flagged;
      }
    } else {
      return json({
        error: "kind must be text | image | video_frames",
      }, 400);
    }

    const { decision, reasons } = decideFromScores(scores, sportsContext);

    // Borderline content: enqueue for async human review (content stays publishable).
    if (decision === "review" && contentRef) {
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (serviceKey) {
        const admin = createClient(supabaseUrl, serviceKey);
        await admin.from("moderation_queue").insert({
          content_type: contentType,
          content_ref: contentRef,
          uploader_user_id: user.id,
          decision_hint: "review",
          scores,
          status: "pending",
        });
      }
    }

    return json({
      decision,
      flagged,
      scores,
      reasons,
      sportsContext,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});
