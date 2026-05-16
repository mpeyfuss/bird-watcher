import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Button } from "./Button";

export const ConnectWalletButton = () => {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
        mounted,
      }) => {
        if (!mounted) return null;

        if (!account || !chain) {
          return <Button onClick={openConnectModal}>connect wallet</Button>;
        }

        if (chain.unsupported) {
          return (
            <Button danger onClick={openChainModal}>
              wrong network
            </Button>
          );
        }

        return (
          <Button onClick={openAccountModal}>{account.displayName}</Button>
        );
      }}
    </ConnectButton.Custom>
  );
};
