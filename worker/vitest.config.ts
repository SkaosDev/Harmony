import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: { bindings: { ALLOWED_SPOTIFY_IDS: "alice, bob" } },
    }),
  ],
  test: { setupFiles: ["./test/setup.ts"] },
});
