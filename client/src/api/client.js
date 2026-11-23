import axios from "axios";

const node = axios.create({ baseURL: "/api", timeout: 90000 });
const ai   = axios.create({ baseURL: "/ai",  timeout: 60000 });

export const api = {
  health:        () => node.get("/health"),
  debug:         () => node.get("/debug"),
  models:        () => node.get("/models"),
  topics:        () => node.get("/topics"),
  search:        (q) => node.get("/search", { params: { q } }),
  chapter:       (slug) => node.get(`/topic/${slug}`),
  exercises:     (topic) => node.get("/exercises", { params: { topic } }),
  certifications:(topic) => node.get("/certifications", { params: { topic } }),
  resources:     (topic) => node.get("/resources", { params: { topic } }),
  leaderboard:   () => node.get("/leaderboard"),
  translate:     (text, target_language) =>
    ai.post("/translate", { text, target_language, source_language: "en" }),
  chat:          (payload) => ai.post("/chat", payload),
  grade:         (payload) => ai.post("/grade", payload),
};
