// Next.js configuration for a frontend repository.
//
// Two shapes, chosen by one variable. See knowledge/frontend/AGENTS.md.
//
//   npm run dev                    Node.js runtime on the host, for development.
//   NEXT_OUTPUT=export next build  Static export into out/. Only the Dockerfile sets it.
//
// Do not set `output` any other way, and do not add rewrites, redirects or headers
// here: a static export cannot honor them.

import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: process.env.NEXT_OUTPUT === "export" ? "export" : undefined,

  // A static export has no image optimization server.
  images: { unoptimized: true },
};

export default nextConfig;
