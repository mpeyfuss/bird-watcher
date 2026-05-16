import "@rainbow-me/rainbowkit/styles.css";
import {
  RainbowKitProvider,
  type AvatarComponent,
  type DisclaimerComponent,
  type Theme,
  darkTheme,
} from "@rainbow-me/rainbowkit";
import { WagmiProvider } from "wagmi";
import { QueryClientProvider, QueryClient } from "@tanstack/react-query";
import { type ReactNode } from "react";
import { web3Config } from "./web3Config";

const queryClient = new QueryClient();

const base = darkTheme();
const terminalTheme: Theme = {
  ...base,
  colors: {
    ...base.colors,
    accentColor: "#7dff7d",
    accentColorForeground: "#0a0e0a",
    modalBackground: "#0a0e0a",
    modalBorder: "#6ba36b",
    modalText: "#b5f5b5",
    modalTextSecondary: "#6ba36b",
  },
  fonts: {
    body: "'JetBrains Mono', ui-monospace, Consolas, monospace",
  },
  radii: {
    ...base.radii,
    actionButton: "0px",
    connectButton: "0px",
    menuButton: "0px",
    modal: "0px",
    modalMobile: "0px",
  },
};

const CustomAvatar: AvatarComponent = ({ address, ensImage, size }) => {
  const style = { width: size, height: size, borderRadius: "50%" };
  return ensImage ? (
    <img src={ensImage} style={style} />
  ) : (
    <div
      style={{
        ...style,
        backgroundImage: `linear-gradient(135deg, #${address.slice(2, 5)}, #${address.slice(-3)})`,
      }}
    />
  );
};

const Disclaimer: DisclaimerComponent = ({ Text, Link }) => (
  <Text>
    By connecting your wallet, you agree to the{" "}
    <Link href="https://transientlabs.xyz/terms">Terms of Service</Link> and{" "}
    <Link href="https://transientlabs.xyz/privacy-policy">Privacy Policy</Link>
  </Text>
);

export const Web3Provider = ({ children }: { children: ReactNode }) => {
  return (
    <WagmiProvider config={web3Config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          avatar={CustomAvatar}
          theme={terminalTheme}
          appInfo={{ disclaimer: Disclaimer }}
          modalSize="compact"
        >
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
};
