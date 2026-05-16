import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { http } from "wagmi";
import { mainnet } from "wagmi/chains";

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;
if (!projectId) {
  throw new Error("VITE_WALLETCONNECT_PROJECT_ID is not set");
}

export const web3Config = getDefaultConfig({
  appName: "Bird Watcher",
  appDescription:
    "An automated observation contract for the onchain Birds project, driven by Chainlink Automation.",
  projectId,
  chains: [mainnet],
  transports: {
    [mainnet.id]: http("https://ethereum-rpc.publicnode.com"),
  },
  ssr: false,
});
