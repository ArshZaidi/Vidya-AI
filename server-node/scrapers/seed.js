const fs = require("fs");
const path = require("path");

const dataDir = path.join(__dirname, "../data");
const chaptersDir = path.join(dataDir, "chapters");
fs.mkdirSync(chaptersDir, { recursive: true });

const chapters = {
  photosynthesis: {
    slug: "photosynthesis",
    title: "Photosynthesis",
    summary: "How plants convert light energy into chemical energy stored in glucose.",
    subject: "Biology",
    language: "en",
    readingTimeMinutes: 8,
    youtubeId: "uixxJtJPVXk",
    subtitlesUrl: "/subtitles/photosynthesis.vtt",
    sections: [
      { heading: "What is Photosynthesis?",
        body: "Photosynthesis is the process by which green plants, algae, and some bacteria convert light energy into chemical energy stored in glucose. It produces the oxygen we breathe and forms the base of most food chains.\n\n6CO2 + 6H2O + light → C6H12O6 + 6O2" },
      { heading: "Where Does It Happen?",
        body: "Photosynthesis takes place inside chloroplasts, mainly in leaves. Chloroplasts contain chlorophyll, which absorbs blue and red light while reflecting green light — which is why leaves look green." },
      { heading: "Two Stages at a Glance",
        type: "table",
        headers: ["Stage", "Location", "Inputs", "Outputs"],
        rows: [
          ["Light-dependent reactions", "Thylakoid membrane", "H2O, light, ADP, NADP+", "O2, ATP, NADPH"],
          ["Calvin cycle", "Stroma", "CO2, ATP, NADPH", "Glucose (G3P), ADP, NADP+"],
        ] },
      { heading: "Why It Matters",
        body: "Photosynthesis is the primary source of all food on Earth and the main source of oxygen in the atmosphere. Without it, complex life as we know it would not exist." },
    ],
    keyTerms: [
      { term: "Chlorophyll", definition: "Green pigment that absorbs light." },
      { term: "Chloroplast", definition: "Organelle where photosynthesis occurs." },
      { term: "ATP", definition: "Energy-carrying molecule from light reactions." },
    ],
  },
  "newtons-laws": {
    slug: "newtons-laws",
    title: "Newton's Laws of Motion",
    summary: "The three foundational laws that describe motion and forces.",
    subject: "Physics",
    language: "en",
    readingTimeMinutes: 10,
    youtubeId: "kKKM8Y-u7ds",
    subtitlesUrl: "/subtitles/newtons-laws.vtt",
    sections: [
      { heading: "First Law — Inertia",
        body: "An object stays at rest, or in uniform motion, unless acted on by a net external force. This is why passengers jerk forward when a bus brakes suddenly." },
      { heading: "Second Law — F = ma",
        body: "Acceleration is proportional to net force and inversely proportional to mass: F = m × a." },
      { heading: "Third Law — Action & Reaction",
        body: "For every action there is an equal and opposite reaction. When you push a wall, the wall pushes back with the same force." },
      { heading: "Summary Table",
        type: "table",
        headers: ["Law", "Statement", "Example"],
        rows: [
          ["1st", "Object in motion stays in motion", "Coffee cup sliding on a car dashboard"],
          ["2nd", "F = m × a", "Heavier cart needs more force to accelerate"],
          ["3rd", "Equal and opposite reaction", "Rocket pushes gas down, gas pushes rocket up"],
        ] },
    ],
    keyTerms: [
      { term: "Inertia", definition: "Resistance to changes in motion." },
      { term: "Net force", definition: "Vector sum of all forces on an object." },
    ],
  },
  "python-basics": {
    slug: "python-basics",
    title: "Python Basics",
    summary: "Variables, control flow, and functions.",
    subject: "Computer Science",
    language: "en",
    readingTimeMinutes: 12,
    youtubeId: "rfscVS0vtbw",
    subtitlesUrl: "/subtitles/python-basics.vtt",
    sections: [
      { heading: "Variables", body: "Assign values to names without declaring types:\nage = 15\nname = 'Ada'" },
      { heading: "Control Flow", body: "if/elif/else for branching, for/while for loops. Indentation defines blocks." },
      { heading: "Functions", body: "Define with def, return with return:\ndef square(x):\n    return x * x" },
      { heading: "Data Types",
        type: "table",
        headers: ["Type", "Example", "Mutable?"],
        rows: [
          ["int", "42", "No"],
          ["str", "'hello'", "No"],
          ["list", "[1, 2, 3]", "Yes"],
          ["dict", "{'a': 1}", "Yes"],
        ] },
    ],
    keyTerms: [
      { term: "int", definition: "Integer type." },
      { term: "list", definition: "Ordered mutable sequence." },
    ],
  },
};

for (const [slug, ch] of Object.entries(chapters)) {
  fs.writeFileSync(path.join(chaptersDir, `${slug}.json`), JSON.stringify(ch, null, 2));
}

const exercises = {
  photosynthesis: [{ id: "photo-ex1", type: "multiple-choice",
    question: "Which organelle is the main site of photosynthesis?",
    options: ["Mitochondrion", "Chloroplast", "Nucleus", "Ribosome"],
    answer: "Chloroplast",
    explanation: "Chloroplasts contain chlorophyll and host both stages." }],
  "newtons-laws": [{ id: "nl-ex1", type: "multiple-choice",
    question: "A 2 kg object accelerates at 3 m/s². What is the net force?",
    options: ["1.5 N", "5 N", "6 N", "0.67 N"],
    answer: "6 N",
    explanation: "F = m × a = 2 × 3 = 6 N." }],
  "python-basics": [{ id: "py-ex1", type: "coding",
    question: "Write a function square(x) that returns x * x.",
    modelAnswer: "def square(x):\n    return x * x" }],
};

const certifications = {
  photosynthesis: [
    { title: "Khan Academy — Photosynthesis", url: "https://www.khanacademy.org/science/biology/photosynthesis-in-plants" },
    { title: "NPTEL — Plant Physiology", url: "https://nptel.ac.in/courses/102106053" }],
  "newtons-laws": [
    { title: "Khan Academy — Forces & Newton's Laws", url: "https://www.khanacademy.org/science/physics/forces-newtons-laws" },
    { title: "MIT OCW — Classical Mechanics", url: "https://ocw.mit.edu/courses/8-01sc-classical-mechanics-fall-2016/" }],
  "python-basics": [
    { title: "freeCodeCamp — Python", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/" },
    { title: "Coursera — Python for Everybody", url: "https://www.coursera.org/specializations/python" }],
};

const resources = {
  photosynthesis: [{ title: "Photosynthesis — Crash Course Biology", url: "https://www.youtube.com/watch?v=uixxJtJPVXk", type: "video" }],
  "newtons-laws": [{ title: "Newton's Laws — Crash Course Physics", url: "https://www.youtube.com/watch?v=kKKM8Y-u7ds", type: "video" }],
  "python-basics": [{ title: "Python Tutorial — freeCodeCamp", url: "https://www.youtube.com/watch?v=rfscVS0vtbw", type: "video" }],
};

const leaderboard = { users: [
  { name: "Aarav", xp: 2400, credits: 120, rank: 1 },
  { name: "Mei", xp: 2100, credits: 100, rank: 2 },
  { name: "Diego", xp: 1850, credits: 90, rank: 3 },
  { name: "Fatima", xp: 1600, credits: 75, rank: 4 },
  { name: "You (demo)", xp: 0, credits: 0, rank: 5, isDemoUser: true },
]};

fs.writeFileSync(path.join(dataDir, "exercises.json"), JSON.stringify(exercises, null, 2));
fs.writeFileSync(path.join(dataDir, "certifications.json"), JSON.stringify(certifications, null, 2));
fs.writeFileSync(path.join(dataDir, "resources.json"), JSON.stringify(resources, null, 2));
fs.writeFileSync(path.join(dataDir, "leaderboard.json"), JSON.stringify(leaderboard, null, 2));

console.log("Seed complete with YouTube IDs and tables.");
