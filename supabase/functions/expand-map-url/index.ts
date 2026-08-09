// functions/expand-map-url/index.ts
import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
  try {
    const { shortUrl } = await req.json();

    if (!shortUrl || !shortUrl.startsWith("https://maps.app.goo.gl/")) {
      return new Response(JSON.stringify({ error: "Invalid short URL" }), { status: 400 });
    }

    // Follow redirects to expand the short URL
    const res = await fetch(shortUrl, { redirect: "follow" });

    if (!res.url) {
      return new Response(JSON.stringify({ error: "Failed to expand URL" }), { status: 500 });
    }

    // Convert final URL into embed format
    // Example: https://www.google.com/maps/place/...  →  https://www.google.com/maps/embed?pb=...
    const expandedUrl = res.url;

    let embedUrl: string;
    if (expandedUrl.includes("/maps/place/") || expandedUrl.includes("/maps/@")) {
      embedUrl = expandedUrl.replace("https://www.google.com/maps", "https://www.google.com/maps/embed");
    } else {
      embedUrl = expandedUrl; // fallback
    }

    return new Response(JSON.stringify({ embedUrl }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
