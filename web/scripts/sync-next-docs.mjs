// Copies the App Router docs bundled with the installed `next` into docs/nextjs/<version>/.
// Run after upgrading Next.js:  npm run docs:sync   (then update the version in AGENTS.md/CLAUDE.md/docs/README.md)
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";

const nextDir = join("node_modules", "next");
const srcDocs = join(nextDir, "dist", "docs");
if (!existsSync(srcDocs)) {
  console.error("node_modules/next/dist/docs not found — run `npm install` first.");
  process.exit(1);
}

const { version } = JSON.parse(readFileSync(join(nextDir, "package.json"), "utf8"));
const root = join("docs", "nextjs");
const dest = join(root, version);

rmSync(root, { recursive: true, force: true }); // drop stale versions
mkdirSync(dest, { recursive: true });
for (const entry of ["01-app", "03-architecture", "index.md"]) {
  cpSync(join(srcDocs, entry), join(dest, entry), { recursive: true });
}
console.log(`Synced Next.js ${version} docs -> ${dest}`);
console.log("Now update the version path in AGENTS.md, CLAUDE.md and docs/README.md.");
