const fs = require("fs");
const path = require("path");
const axios = require("axios");
const cheerio = require("cheerio");

async function scrape(url, slug) {
  console.log(`Fetching ${url} ...`);
  const { data } = await axios.get(url, {
    headers: { "User-Agent": "SDG4StudyApp/1.0 (educational prototype)" },
    timeout: 20000,
  });
  const $ = cheerio.load(data);
  const title = $("h1").first().text().trim() || slug;
  const sections = [];

  $("h2").each((_, el) => {
    const heading = $(el).text().trim();
    let body = "";
    let next = $(el).next();
    while (next.length && !next.is("h2")) {
      if (next.is("p")) body += next.text().trim() + "\n\n";
      next = next.next();
    }
    if (heading && body.trim()) sections.push({ heading, body: body.trim() });
  });

  if (!sections.length) {
    const paras = $("p").map((_, el) => $(el).text().trim()).get().filter(Boolean);
    sections.push({ heading: "Overview", body: paras.join("\n\n") });
  }

  const chapter = {
    slug, title,
    summary: (sections[0]?.body || "").slice(0, 180) + "...",
    subject: "General", language: "en",
    readingTimeMinutes: Math.ceil(sections.reduce((s, x) => s + x.body.split(/\s+/).length, 0) / 200),
    sections, keyTerms: [],
    subtitlesUrl: `/subtitles/${slug}.vtt`, videoUrl: "",
  };

  const outDir = path.join(__dirname, "../data/chapters");
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, `${slug}.json`), JSON.stringify(chapter, null, 2));
  console.log(`Saved data/chapters/${slug}.json`);
}

const [, , url, slug] = process.argv;
if (!url || !slug) { console.log("Usage: node scrapers/scrape.js <url> <slug>"); process.exit(1); }
scrape(url, slug).catch((e) => { console.error("Scrape failed:", e.message); process.exit(1); });
