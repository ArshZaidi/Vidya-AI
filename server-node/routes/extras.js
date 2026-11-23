const express = require("express");
const fs = require("fs");
const path = require("path");
const router = express.Router();
const { generateExercises, listAvailableModels } = require("../services/ai");

const dataDir = path.join(__dirname, "../data");
const chaptersDir = path.join(dataDir, "chapters");
const readJSON = (n) => {
  const p = path.join(dataDir, n);
  return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf-8")) : {};
};
const writeJSON = (n, o) =>
  fs.writeFileSync(path.join(dataDir, n), JSON.stringify(o, null, 2));
const loadChapter = (slug) => {
  const p = path.join(chaptersDir, `${slug}.json`);
  return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf-8")) : null;
};

router.get("/exercises", async (req, res) => {
  const topic = req.query.topic;
  const all = readJSON("exercises.json");
  if (all[topic]) return res.json({ exercises: { [topic]: all[topic] } });
  const chapter = loadChapter(topic);
  if (!chapter) return res.json({ exercises: {} });
  try {
    const gen = await generateExercises(chapter);
    all[topic] = gen;
    writeJSON("exercises.json", all);
    res.json({ exercises: { [topic]: gen } });
  } catch (err) {
    console.error("[exercises/generate]", err.message);
    res.json({ exercises: { [topic]: [] } });
  }
});

router.get("/certifications", (req, res) => {
  const all = readJSON("certifications.json");
  const t = req.query.topic;
  res.json({ certifications: t && all[t] ? { [t]: all[t] } : all });
});

router.get("/resources", (req, res) => {
  const all = readJSON("resources.json");
  const t = req.query.topic;
  res.json({ resources: t && all[t] ? { [t]: all[t] } : all });
});

router.get("/leaderboard", (req, res) => res.json(readJSON("leaderboard.json")));

router.get("/debug", (req, res) => {
  const key = (process.env.GEMINI_API_KEY || "").trim();
  res.json({
    provider: "gemini",
    gemini_key_present: !!key,
    gemini_key_prefix: key.slice(0, 8),
    chapters: fs.existsSync(chaptersDir)
      ? fs.readdirSync(chaptersDir).map((f) => f.replace(".json", ""))
      : [],
  });
});

router.get("/models", async (req, res) => res.json(await listAvailableModels()));

module.exports = router;
