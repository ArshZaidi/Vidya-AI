export default {
  darkMode: 'class',
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        pistachio: 'rgb(var(--pistachio-rgb) / <alpha-value>)',
        ink: 'rgb(var(--ink-rgb) / <alpha-value>)',
        raspberry: 'rgb(var(--raspberry-rgb) / <alpha-value>)',
        bronze: 'rgb(var(--bronze-rgb) / <alpha-value>)',
        bg: 'rgb(var(--bg-rgb) / <alpha-value>)',
        surface: 'rgb(var(--surface-rgb) / <alpha-value>)',
      },
      fontFamily: {
        display: ['"Proxima Nova Condensed"', 'Oswald', 'sans-serif'],
        body: ['Sailors', '"DM Serif Display"', 'serif'],
      },
    },
  },
};
