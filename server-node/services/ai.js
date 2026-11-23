const axios = require("axios");

const PREFERRED = [
  "gemini-3.5-flash-lite",
  "gemini-3.8-flash",
  "gemini-3.5-flash",
  "gemini-3.1-flash-lite",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.5-pro",
];

const EXCLUDE = /(tts|live|image|embedding|imagen|veo|native-audio|aqa)/i;
let _models = null, _cacheAt = 0;
const TTL = 3600 * 1000;

async function discoverModels(key) {
  if (_models && Date.now() - _cacheAt < TTL) return _models;
  try {
    const { data } = await axios.get(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${key}`,
      { timeout: 10000 }
    );
    const valid = (data.models || [])
      .filter((m) => (m.supportedGenerationMethods || []).includes("generateContent"))
      .map((m) => m.name.replace(/^models\//, ""))
      .filter((n) => !EXCLUDE.test(n));
    const ordered = [
      ...PREFERRED.filter((p) => valid.includes(p)),
      ...valid.filter((v) => !PREFERRED.includes(v)).sort(),
    ];
    if (ordered.length) {
      _models = ordered;
      _cacheAt = Date.now();
      console.log("[gemini] discovered:", ordered.slice(0, 4).join(", "));
      return _models;
    }
  } catch (e) {
    console.warn("[gemini] ListModels:", e.message);
  }
  return PREFERRED;
}

const supportsThinking = (m) => "2.5" in m || m.startsWith("gemini-3");

async function callGemini(prompt, { jsonMode = false, maxTokens = 4000, fast = false } = {}) {
  const key = (process.env.GEMINI_API_KEY || "").trim();
  if (!key) throw new Error("GEMINI_API_KEY missing in server-node/.env");

  const all = await discoverModels(key);
  const models = fast
    ? [
        ...all.filter((m) => m.includes("lite")),
        ...all.filter((m) => !m.includes("lite")),
      ].slice(0, 3)
    : all.slice(0, 5);

  let lastErr = "";

  for (const model of models) {
    const variations = fast && supportsThinking(model) ? [true, false] : [false];

    for (const useThinking of variations) {
      const payload = {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: maxTokens,
          ...(jsonMode ? { responseMimeType: "application/json" } : {}),
        },
      };
      if (useThinking) {
        payload.generationConfig.thinkingConfig = { thinkingBudget: 0 };
      }

      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
      try {
        const { data } = await axios.post(url, payload, { timeout: 30000 });
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          _models = [model, ...all.filter((m) => m !== model)];
          return text;
        }
        lastErr = `${model}: empty response`;
        break;
      } catch (err) {
        const status = err.response?.status;
        const body = JSON.stringify(err.response?.data || {}).slice(0, 250);
        lastErr = `${model}${useThinking ? "+think" : ""}: ${status || "network"} — ${body}`;

        if (status === 401 || status === 403) {
          throw new Error(`Gemini auth error (${status}). Details: ${body}`);
        }
        if (status === 400 && useThinking) continue; // retry without thinking
        if (status === 503) {
          await new Promise((r) => setTimeout(r, 1000));
          continue;
        }
        break; // try next model
      }
    }
  }
  throw new Error(`All models failed. Last: ${lastErr}`);
}

function parseJSON(raw) {
  return JSON.parse(
    raw.trim()
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/```\s*$/i, "")
  );
}

async function generateChapter(topic, slug) {
  const prompt = `Generate a study chapter about "${topic}". Return ONLY valid JSON:

{"slug":"${slug}","title":"${topic}","summary":"one sentence","subject":"Biology|Physics|History|CS|etc","language":"en","readingTimeMinutes":8,"youtubeId":"","sections":[{"heading":"Introduction","body":"3-5 sentences"},{"heading":"Key Concept","body":"3-5 sentences"},{"heading":"Comparison","type":"table","headers":["A","B","C"],"rows":[["1","2","3"],["4","5","6"]]},{"heading":"Application","body":"3-5 sentences"}],"keyTerms":[{"term":"t1","definition":"d1"},{"term":"t2","definition":"d2"},{"term":"t3","definition":"d3"}]}

RULES: 4-6 sections, ≥1 table section, 3-6 keyTerms, factual, substantive bodies, youtubeId ""`;

  const chapter = parseJSON(await callGemini(prompt, { jsonMode: true, maxTokens: 6000 }));
  chapter.slug = slug;
  if (!Array.isArray(chapter.sections) || !chapter.sections.length) {
    throw new Error("No sections generated");
  }
  return chapter;
}

async function generateExercises(chapter) {
  const prompt = `2 MCQs for "${chapter.title}" (${chapter.subject}). Return ONLY JSON array:
[{"id":"gen-1","type":"multiple-choice","question":"...","options":["A","B","C","D"],"answer":"A","explanation":"one sentence"},{"id":"gen-2","type":"multiple-choice","question":"...","options":["A","B","C","D"],"answer":"B","explanation":"one sentence"}]`;
  return parseJSON(await callGemini(prompt, { jsonMode: true, maxTokens: 2000 }));
}

async function listAvailableModels() {
  const key = (process.env.GEMINI_API_KEY || "").trim();
  if (!key) return { error: "no key" };
  try {
    const models = await discoverModels(key);
    return { count: models.length, models };
  } catch (e) {
    return { error: e.message };
  }
}

module.exports = { generateChapter, generateExercises, callGemini, listAvailableModels };
