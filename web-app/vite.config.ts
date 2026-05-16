import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const walletConnectProjectId = env.VITE_WALLETCONNECT_PROJECT_ID?.trim();

  if (!walletConnectProjectId) {
    throw new Error(
      "Missing VITE_WALLETCONNECT_PROJECT_ID. Set it in .env.local for local development and in Vercel project environment variables for deployed builds.",
    );
  }

  return {
    plugins: [react()],
  };
});
