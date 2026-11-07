// Points the app at your GitHub repository (updates, issue links, Discord icon).
// Usage: npm run set-repo -- your-name/yomi
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const repo = process.argv[2] ?? "";
if (!/^[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(repo)) {
  console.error("Usage: npm run set-repo -- your-name/repo-name");
  process.exit(1);
}

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const targets = [
  ["src-tauri/src/branding.rs", /"[^"\s]+\/[^"\s]+"(?=\s*\n\s*\};)/, `"${repo}"`],
  ["ui/js/links.js", /export const REPO = "[^"]*";/, `export const REPO = "https://github.com/${repo}";`],
];

for (const [file, pattern, replacement] of targets) {
  const path = join(root, file);
  const before = readFileSync(path, "utf8");
  if (!pattern.test(before)) {
    console.error(`Couldn't find the repository setting in ${file}.`);
    process.exit(1);
  }
  writeFileSync(path, before.replace(pattern, replacement));
  console.log(`${file} → ${repo}`);
}
