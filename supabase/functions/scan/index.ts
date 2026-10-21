// Pinpoint "scan" edge function: reads a photo of a bowling lane screen with Google Gemini.
// Deploy in Supabase → Edge Functions → Deploy a new function → Via Editor, name it "scan".
// Add a secret named GEMINI_API_KEY (Edge Functions → Secrets) with a free key from aistudio.google.com.
// Optional secret GEMINI_MODEL to force a specific model.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROMPT = `This photo shows a bowling alley scoring monitor (or a printed score sheet). Read it carefully.
For EVERY bowler visible, transcribe all 10 frames exactly as the marks are displayed, plus the final total shown on screen.
Mark notation per frame, as one string: "X" strike, "/" spare, "-" miss or gutter (also use "-" for a foul or a 0), digits 1-9 for pin counts.
Frames 1-9: a strike is just "X"; otherwise two marks like "72", "8/", "-5", "9-". Frame 10: up to three marks like "X9/", "XXX", "7/X", "81".
If a frame hasn't been bowled or you can't read it, use "". Do not compute totals yourself: copy the total printed on screen, or null if none is visible.
Reply with only JSON in this shape:
{"bowlers":[{"name":"JAKE","frames":["X","7/","9-","X","X","8/","X","X","9/","XX8"],"total":213}]}
If no bowling score is visible, reply {"bowlers":[]}.`;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return json({ error: "Scanning isn't set up yet: the GEMINI_API_KEY secret is missing." }, 500);

  let image = "", mimeType = "image/jpeg";
  try {
    const body = await req.json();
    image = String(body.image || "");
    if (body.mimeType) mimeType = String(body.mimeType);
  } catch {
    return json({ error: "Send JSON with an image field." }, 400);
  }
  if (!image) return json({ error: "No image was sent." }, 400);
  if (image.length > 10_000_000) return json({ error: "That photo is too large." }, 413);

  const models = [Deno.env.get("GEMINI_MODEL"), "gemini-flash-latest", "gemini-2.5-flash", "gemini-2.0-flash"]
    .filter((m): m is string => !!m);

  let lastError = "Scan service error";
  for (const model of models) {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        contents: [{ parts: [{ text: PROMPT }, { inline_data: { mime_type: mimeType, data: image } }] }],
        generationConfig: { responseMimeType: "application/json", temperature: 0 },
      }),
    });
    const data = await r.json().catch(() => ({}));
    if (r.status === 404 || r.status === 400 && /not found|not supported/i.test(data?.error?.message || "")) {
      lastError = data?.error?.message || `Model ${model} unavailable`;
      continue; // try the next model name
    }
    if (r.status === 429) return json({ error: "Too many scans right now. Wait a minute and try again." }, 429);
    if (!r.ok) return json({ error: data?.error?.message || lastError }, 502);

    const text: string = (data?.candidates?.[0]?.content?.parts || []).map((p: { text?: string }) => p.text || "").join("");
    let out: unknown;
    try { out = JSON.parse(text); }
    catch {
      const m = text.match(/\{[\s\S]*\}/);
      try { out = m ? JSON.parse(m[0]) : { bowlers: [] }; } catch { out = { bowlers: [] }; }
    }
    return json({ ...(out as object), model });
  }
  return json({ error: lastError }, 502);
});
