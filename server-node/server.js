require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");
const contentRoutes = require("./routes/content");
const extrasRoutes = require("./routes/extras");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: ["http://localhost:5173", "http://localhost:3000"] }));
app.use(express.json({ limit: "5mb" }));

app.use("/api", contentRoutes);
app.use("/api", extrasRoutes);
app.get("/api/health", (req, res) =>
  res.json({ status: "ok", service: "node-backend", time: new Date().toISOString() })
);

const clientDist = path.join(__dirname, "../client/dist");
app.use(express.static(clientDist));
app.get("*", (req, res) => {
  if (req.path.startsWith("/api")) return res.status(404).json({ error: "Not found" });
  res.sendFile(path.join(clientDist, "index.html"), (err) => {
    if (err) res.status(404).send("Client build not found. Run `npm run build` in /client.");
  });
});

app.listen(PORT, () => console.log(`[node] Listening on http://localhost:${PORT}`));
