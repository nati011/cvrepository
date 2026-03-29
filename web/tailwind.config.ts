import type { Config } from "tailwindcss";

export default {
  darkMode: "class",
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Montserrat Variable"', "Montserrat", "ui-sans-serif", "system-ui", "sans-serif"],
        display: ['"Raleway Variable"', "Raleway", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: ["var(--font-geist-mono)", "ui-monospace", "monospace"],
      },
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
        brand: {
          primary: "#02404F",
          secondary: "#EB7D23",
          dark: "#0A1A1F",
          light: "#F3F5F6",
        },
      },
      boxShadow: {
        card: "0 1px 2px 0 rgb(2 64 79 / 0.06), 0 1px 3px 0 rgb(10 26 31 / 0.08)",
      },
    },
  },
  plugins: [],
} satisfies Config;
