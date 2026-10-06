import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const POSITIONS = new Set([
  "Goalkeeper",
  "Defender",
  "Midfielder",
  "Attacker",
]);
const MAX_BATCH = 20;

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: cors });
}

function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function normalizeUsername(raw: unknown): string {
  return String(raw ?? "").trim();
}

function normalizeName(raw: unknown): string {
  return String(raw ?? "").trim().replace(/\s+/g, " ");
}

function isAllowedImageUrl(raw: string): boolean {
  if (raw.startsWith("lib/assets/images/avatars/")) return true;
  try {
    const url = new URL(raw);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !supabaseAnon || !serviceRole) {
    return json({ error: "Server is not configured" }, 500);
  }

  const accessToken = bearerToken(req);
  if (!accessToken) return json({ error: "Unauthorized" }, 401);

  const userClient = createClient(supabaseUrl, supabaseAnon, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser(accessToken);
  if (userError || !user || user.is_anonymous) {
    return json({ error: "Unauthorized" }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRole);
  const { data: staff, error: staffError } = await admin
    .from("players")
    .select("id, account_type, deleted_at")
    .eq("id", user.id)
    .maybeSingle();
  if (
    staffError ||
    !staff ||
    staff.deleted_at != null ||
    staff.account_type !== "technical_staff"
  ) {
    return json({ error: "Only technical staff can manage player accounts" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }

  const action = String(body.action ?? "");
  if (action === "create") {
    return await createPlayers(admin, user.id, body);
  }
  if (action === "enable_login") {
    return await enableLogin(admin, user.id, body);
  }
  if (action === "update") {
    return await updatePlayer(admin, user.id, body);
  }
  return json({ error: "Unknown action" }, 400);
});

async function createPlayers(
  admin: ReturnType<typeof createClient>,
  staffId: string,
  body: Record<string, unknown>,
) {
  const raw = body.players;
  if (!Array.isArray(raw) || raw.length === 0) {
    return json({ error: "Add at least one player" }, 400);
  }
  if (raw.length > MAX_BATCH) {
    return json({ error: `You can create at most ${MAX_BATCH} players at once` }, 400);
  }

  const seen = new Set<string>();
  const rows: Array<{
    player_name: string;
    username: string;
    position: string;
    image_url: string;
  }> = [];

  for (const item of raw) {
    const map = item && typeof item === "object"
      ? item as Record<string, unknown>
      : {};
    const playerName = normalizeName(map.player_name);
    const username = normalizeUsername(map.username);
    const position = String(map.position ?? "").trim();
    const imageUrl = String(map.image_url ?? "").trim();

    if (playerName.length < 2) {
      return json({ error: "Each player needs a name" }, 400);
    }
    if (playerName.length > 60) {
      return json({ error: "Player names must be 60 characters or fewer" }, 400);
    }
    if (!USERNAME_RE.test(username)) {
      return json({
        error: "Usernames must be 3–20 letters, numbers, or underscores",
      }, 400);
    }
    if (!POSITIONS.has(position)) {
      return json({ error: "Each player needs a position" }, 400);
    }
    if (!isAllowedImageUrl(imageUrl)) {
      return json({
        error: "Each player needs a photo so match officials can identify them",
      }, 400);
    }
    const usernameKey = username.toLowerCase();
    if (seen.has(usernameKey)) {
      return json({ error: `Username @${username} is used more than once` }, 400);
    }
    seen.add(usernameKey);
    rows.push({
      player_name: playerName,
      username,
      position,
      image_url: imageUrl,
    });
  }

  for (const row of rows) {
    const { data: available, error } = await admin.rpc("is_username_available", {
      p_username: row.username,
    });
    if (error) return json({ error: "Could not check usernames" }, 500);
    if (available !== true) {
      return json({ error: `@${row.username} is already taken` }, 409);
    }
  }

  const created: Array<Record<string, unknown>> = [];
  for (const row of rows) {
    const { data, error } = await admin
      .from("players")
      .insert({
        player_name: row.player_name,
        username: row.username,
        position: row.position,
        image_url: row.image_url,
        account_type: "player",
        created_by: staffId,
      })
      .select("id, player_name, username, position, image_url, login_enabled_at, created_at")
      .single();
    if (error || !data) {
      return json({
        error: error?.message?.includes("players_username_unique")
          ? `@${row.username} is already taken`
          : "Could not create players",
        created,
      }, 500);
    }
    created.push(data);
  }

  return json({ players: created });
}

function parsePlayerDetails(body: Record<string, unknown>) {
  const playerName = normalizeName(body.player_name);
  const username = normalizeUsername(body.username);
  const position = String(body.position ?? "").trim();
  const imageUrl = String(body.image_url ?? "").trim();

  if (playerName.length < 2) {
    return { error: "Each player needs a name" };
  }
  if (playerName.length > 60) {
    return { error: "Player names must be 60 characters or fewer" };
  }
  if (!USERNAME_RE.test(username)) {
    return { error: "Usernames must be 3–20 letters, numbers, or underscores" };
  }
  if (!POSITIONS.has(position)) {
    return { error: "Each player needs a position" };
  }
  if (!isAllowedImageUrl(imageUrl)) {
    return {
      error: "Each player needs a photo so match officials can identify them",
    };
  }
  return { playerName, username, position, imageUrl };
}

async function updatePlayer(
  admin: ReturnType<typeof createClient>,
  staffId: string,
  body: Record<string, unknown>,
) {
  const playerId = String(body.player_id ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(playerId)) {
    return json({ error: "Invalid player" }, 400);
  }

  const details = parsePlayerDetails(body);
  if ("error" in details && details.error) {
    return json({ error: details.error }, 400);
  }
  const { playerName, username, position, imageUrl } = details as {
    playerName: string;
    username: string;
    position: string;
    imageUrl: string;
  };

  const { data: player, error: playerError } = await admin
    .from("players")
    .select("id, created_by, deleted_at, login_enabled_at")
    .eq("id", playerId)
    .maybeSingle();
  if (playerError || !player) {
    return json({ error: "Player not found" }, 404);
  }
  if (player.deleted_at != null) {
    return json({ error: "This player account was deleted" }, 400);
  }
  if (player.created_by !== staffId) {
    return json({ error: "You can only edit players you created" }, 403);
  }
  if (player.login_enabled_at != null) {
    return json({
      error: "This player already has a login. You can no longer edit their details.",
    }, 409);
  }

  const { data: available, error: availableError } = await admin.rpc(
    "is_username_available",
    {
      p_username: username,
      p_exclude_player_id: playerId,
    },
  );
  if (availableError) return json({ error: "Could not check usernames" }, 500);
  if (available !== true) {
    return json({ error: `@${username} is already taken` }, 409);
  }

  const { data, error } = await admin
    .from("players")
    .update({
      player_name: playerName,
      username,
      position,
      image_url: imageUrl,
    })
    .eq("id", playerId)
    .eq("created_by", staffId)
    .is("login_enabled_at", null)
    .select("id, player_name, username, position, image_url, login_enabled_at, created_at")
    .maybeSingle();
  if (error || !data) {
    return json({ error: "Could not update this player" }, 500);
  }
  return json({ player: data });
}

async function enableLogin(
  admin: ReturnType<typeof createClient>,
  staffId: string,
  body: Record<string, unknown>,
) {
  const playerId = String(body.player_id ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");

  if (!/^[0-9a-f-]{36}$/i.test(playerId)) {
    return json({ error: "Invalid player" }, 400);
  }
  if (!EMAIL_RE.test(email)) {
    return json({ error: "Enter a valid email" }, 400);
  }
  if (password.length < 6) {
    return json({ error: "Password must be at least 6 characters" }, 400);
  }

  const { data: player, error: playerError } = await admin
    .from("players")
    .select("id, created_by, deleted_at, account_type")
    .eq("id", playerId)
    .maybeSingle();
  if (playerError || !player) {
    return json({ error: "Player not found" }, 404);
  }
  if (player.deleted_at != null) {
    return json({ error: "This player account was deleted" }, 400);
  }
  if (player.created_by !== staffId) {
    return json({ error: "You can only set login details for players you created" }, 403);
  }

  const { data: existing, error: getUserError } = await admin.auth.admin
    .getUserById(playerId);

  if (getUserError && !String(getUserError.message ?? "").includes("not found")) {
    return json({ error: "Could not update login details" }, 500);
  }

  if (existing?.user) {
    if (existing.user.last_sign_in_at) {
      return json({
        error: "This player has already signed in. They can manage their own login now.",
      }, 409);
    }
    const { error: updateError } = await admin.auth.admin.updateUserById(
      playerId,
      {
        email,
        password,
        email_confirm: true,
        user_metadata: {
          ...(existing.user.user_metadata ?? {}),
          onboarding_complete: true,
        },
        app_metadata: {
          ...(existing.user.app_metadata ?? {}),
          managed_player: true,
          created_by: staffId,
        },
      },
    );
    if (updateError) {
      return json({
        error: updateError.message?.toLowerCase().includes("already")
          ? "That email is already used by another account"
          : "Could not update login details",
      }, 409);
    }
  } else {
    const { error: createError } = await admin.auth.admin.createUser({
      id: playerId,
      email,
      password,
      email_confirm: true,
      user_metadata: { onboarding_complete: true },
      app_metadata: { managed_player: true, created_by: staffId },
    });
    if (createError) {
      return json({
        error: createError.message?.toLowerCase().includes("already")
          ? "That email is already used by another account"
          : "Could not create login details",
      }, 409);
    }
  }

  const { error: stampError } = await admin
    .from("players")
    .update({ login_enabled_at: new Date().toISOString() })
    .eq("id", playerId)
    .eq("created_by", staffId);
  if (stampError) {
    return json({ error: "Login was created but the profile could not be updated" }, 500);
  }

  return json({ ok: true, player_id: playerId });
}
