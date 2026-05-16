import "./App.css";
import { type ReactNode } from "react";
import { useAccount } from "wagmi";
import { Button } from "./components/Button";
import { ConnectWalletButton } from "./components/ConnectWalletButton";
import { DeployBirdWatcherButton } from "./components/DeployBirdWatcherButton";
import { WatcherAddressInput } from "./components/WatcherAddressInput";
import { useWatcherAddress } from "./hooks/useWatcherAddress";

const BANNER = String.raw`
██████╗ ██╗██████╗ ██████╗     ██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗███████╗██████╗
██╔══██╗██║██╔══██╗██╔══██╗    ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║██╔════╝██╔══██╗
██████╔╝██║██████╔╝██║  ██║    ██║ █╗ ██║███████║   ██║   ██║     ███████║█████╗  ██████╔╝
██╔══██╗██║██╔══██╗██║  ██║    ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║██╔══╝  ██╔══██╗
██████╔╝██║██║  ██║██████╔╝    ╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║███████╗██║  ██║
╚═════╝ ╚═╝╚═╝  ╚═╝╚═════╝      ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
`;

function ManualSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="manual-section">
      <hr className="rule" />
      <h2>{`> ${title}`}</h2>
      <hr className="rule tight" />
      <div className="section-body">{children}</div>
    </section>
  );
}

function WatcherWriteButton({ label }: { label: string }): ReactNode {
  const { isConnected } = useAccount();
  const { watcher } = useWatcherAddress();

  if (!isConnected) return <Button disabled>connect wallet first</Button>;
  if (!watcher) return <Button disabled>deploy or load watcher first</Button>;
  return (
    <Button
      href={`https://etherscan.io/address/${watcher}#writeContract`}
      external
    >
      {label}
    </Button>
  );
}

function App() {
  return (
    <div className="terminal">
      <pre className="banner">{BANNER}</pre>

      <div className="manual">
        <hr className="rule double" />
        <div className="manual-title">OPERATOR'S MANUAL :: v1.0.0</div>
        <hr className="rule double tight" />

        <ManualSection title="WELCOME">
          <p>
            Bird Watcher is an automated observation contract for Birds by{" "}
            <a
              href="https://x.com/nicedayJules"
              target="_blank"
              className="address-link"
            >
              Jules
            </a>{" "}
            +{" "}
            <a
              href="https://x.com/mungimungimungi"
              target="_blank"
              className="address-link"
            >
              Mungi
            </a>
            . Once deployed and wired to Chainlink Automation, your watcher
            scans the active sanctuaries and observes the first eligible bird
            every time a new bird/sanctuary combo pops up.
          </p>
          <p>
            To run your own watcher you will deploy a BirdWatcher contract,
            register an upkeep with Chainlink, fund both sides, and optionally
            give it an identity. Connect a wallet to get started.
          </p>
          <div className="action-row">
            <ConnectWalletButton />
          </div>
        </ManualSection>

        <ManualSection title="1. SET UP YOUR WATCHER">
          <p>
            Most operators only need one BirdWatcher contract. Deploy it once,
            then use the same watcher for the Chainlink Automation and funding
            steps below.
          </p>
          <p>
            The contract is pre-wired to the live Birds and BirdObservations
            contracts on mainnet and ships with sane defaults: observationLimit
            = 1, maxFee = 0.001 ETH, maxGasPrice = 2 gwei.
          </p>
          <div className="action-row">
            <DeployBirdWatcherButton />
          </div>
          <p>
            This is the watcher address this page will use for the remaining
            steps. Deploying again is only for operators who intentionally want
            multiple independent watchers.
          </p>
          <WatcherAddressInput />
        </ManualSection>

        <ManualSection title="2. GET LINK">
          <p>
            Chainlink Automation is paid in LINK. Get at least 1 LINK before
            creating your upkeep. If you buy LINK somewhere other than Uniswap,
            use the mainnet LINK token address:
            0x514910771af9ca656af840dff83e8264ecf986ca.
          </p>
          <div className="action-row">
            <Button
              href="https://app.uniswap.org/swap?chain=mainnet&inputCurrency=NATIVE&outputCurrency=0x514910771af9ca656af840dff83e8264ecf986ca"
              external
            >
              get $LINK on uniswap
            </Button>
          </div>
        </ManualSection>

        <ManualSection title="3. CREATE A CHAINLINK AUTOMATION">
          <p>
            Register a custom-logic upkeep against your watcher in the Chainlink
            Automation app.
          </p>
          <ol className="step-list">
            <li>Open the Chainlink Automation app.</li>
            <li>Paste in your BirdWatcher address from step 1.</li>
            <li>Give the upkeep a name.</li>
            <li>Set the gas limit to 200,000.</li>
            <li>Give it a starting balance of 10 LINK.</li>
            <li>Create the upkeep.</li>
          </ol>
          <p>
            Save the forwarder address Chainlink shows you on the upkeep details
            page; you will need it in step 4.
          </p>
          <div className="action-row">
            <Button href="https://automation.chain.link/" external>
              open automation app
            </Button>
          </div>
        </ManualSection>

        <ManualSection title="4. SET THE FORWARDER">
          <p>
            performUpkeep is permissioned: only the forwarder address Chainlink
            generated for your automation can call it. Set it on your watcher
            via the setForwarder function on the Write Contract tab. Without
            this, the Chainlink automation network will never trigger
            observations.
          </p>
          <div className="action-row">
            <WatcherWriteButton label="set forwarder on etherscan" />
          </div>
        </ManualSection>

        <ManualSection title="5. FUND YOUR WATCHER">
          <p>
            Each observation pays a small fee, roughly $1, to BirdObservations.
            Send ETH to your watcher to cover those fees; you can withdraw
            remaining ETH at any time.
          </p>
          <p>
            Fund the watcher with ~$500 or about 0.25 ETH by sending it directly
            to the watcher address on Ethereum mainnet.
          </p>
        </ManualSection>

        <ManualSection title="6. WATCH BALANCES">
          <p>
            Your Chainlink Automation upkeep has a minimum LINK balance. Keep it
            topped up so the automation stays active.
          </p>
          <p>
            Your watcher also needs enough ETH to pay BirdObservations for each
            observation. If the watcher balance runs low, it will stop reporting
            eligible upkeep work until it is funded again.
          </p>
        </ManualSection>

        <ManualSection title="7. SPONSOR THE PROJECT">
          <p>
            If Bird Watcher is useful to you, consider sending some ETH to
            support continued maintenance.
          </p>
          <p>Donation wallet: 0x40706BCC6ca5886F56d02196BfC844Ea5b099774</p>
        </ManualSection>

        <ManualSection title="8. LINKS">
          <div className="action-row">
            <Button href="https://github.com/mpeyfuss/bird-watcher" external>
              github
            </Button>
            <Button href="https://x.com/mpeyfuss" external>
              mpeyfuss
            </Button>
            <Button href="https://x.com/nicedayJules" external>
              jules
            </Button>
            <Button href="https://x.com/mungimungimungi" external>
              mungi
            </Button>
          </div>
        </ManualSection>

        <hr className="rule" />
        <div className="manual-title">END OF MANUAL</div>
        <hr className="rule tight" />
      </div>
    </div>
  );
}

export default App;
