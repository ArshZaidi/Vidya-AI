const express = require("express");
const fs = require("fs");
const path = require("path");
const router = express.Router();
const { generateChapter } = require("../services/gemini");

const chaptersDir = path.join(__dirname, "../data/chapters");

const loadChapter = (slug) => {
  const p = path.join(chaptersDir, `${slug}.json`);
  return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf-8")) : null;
};
const listChapters = () => {
  if (!fs.existsSync(chaptersDir)) return [];
  return fs.readdirSync(chaptersDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => {
      const d = JSON.parse(fs.readFileSync(path.join(chaptersDir, f), "utf-8"));
      return { slug: f.replace(".json", ""), title: d.title, subject: d.subject };
    });
};
const slugify = (s) => s.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

router.get("/topics", (req, res) => res.json({ topics: listChapters() }));

router.get("/topic/:slug", (req, res) => {
  const chapter = loadChapter(req.params.slug);
  if (!chapter) return res.status(404).json({ error: "Topic not found" });
  res.json(chapter);
});

// Dynamic search — generates any topic via Gemini
router.get("/search", async (req, res) => {
  const q = (req.query.q || "").trim();
  if (!q) return res.status(400).json({ error: "Query required" });

  const slug = slugify(q);

  // 1) Exact local cache
  const exact = loadChapter(slug);
  if (exact) return res.json(exact);

  // 2) Fuzzy match against seeded topics
  const list = listChapters();
  const fuzzy = list.find((c) =>
    c.slug.includes(slug) ||
    slug.includes(c.slug) ||
    c.title.toLowerCase().includes(q.toLowerCase())
  );
  if (fuzzy) return res.json(loadChapter(fuzzy.slug));

  // 3) Generate via Gemini + cache to disk
  try {
    const chapter = await generateChapter(q, slug);
    fs.mkdirSync(chaptersDir, { recursive: true });
    fs.writeFileSync(path.join(chaptersDir, `${slug}.json`), JSON.stringify(chapter, null, 2));
    return res.json(chapter);
  } catch (err) {
    console.error("[search/generate]", err.message);
    // Graceful fallback — return a minimal chapter so demo doesn't break
    const fallback = {
      slug, title: q, summary: `Generated chapter for ${q}`, subject: "General",
      language: "en", readingTimeMinutes: 5, youtubeId: "",
      sections: [{
        heading: `About ${q}`,
        body: `We couldn't generate a full chapter right now (${err.message}). Please try again in a moment, or check that GEMINI_API_KEY is set in server-node/.env.`,
      }],
      keyTerms: [],
    };
    return res.json(fallback);
  }
});

module.exports = router;
