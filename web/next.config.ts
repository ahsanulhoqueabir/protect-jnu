import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // `next dev` would otherwise append a block to AGENTS.md pointing agents at
  // node_modules/next/dist/docs/. The committed docs/nextjs/<version>/ are the
  // sole Next.js reference for this project.
  agentRules: false,
};

export default nextConfig;
