import { useState } from "react";
import { useAccount } from "wagmi";
import { deployContract, waitForTransactionReceipt } from "wagmi/actions";
import { Button } from "./Button";
import { web3Config } from "./web3Config";
import { useWatcherAddress } from "../hooks/useWatcherAddress";
import {
  birdWatcherAbi,
  birdWatcherBytecode,
} from "../contracts/birdWatcher";

type Status = "idle" | "pending" | "mining" | "success" | "error";

const LABELS: Record<Status, string> = {
  idle: "deploy watcher",
  pending: "confirm in wallet...",
  mining: "deploying...",
  success: "deployed",
  error: "retry deploy",
};

export const DeployBirdWatcherButton = () => {
  const { address, isConnected } = useAccount();
  const { watcher, setWatcher } = useWatcherAddress();
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | undefined>();

  if (!isConnected) {
    return <Button disabled>connect wallet first</Button>;
  }

  const onClick = async () => {
    if (!address) return;
    if (
      watcher &&
      !window.confirm(
        "You already have a watcher saved. Deploying again creates a second independent contract and costs gas. Continue?",
      )
    ) {
      return;
    }
    setError(undefined);
    setStatus("pending");
    try {
      const hash = await deployContract(web3Config, {
        abi: birdWatcherAbi,
        bytecode: birdWatcherBytecode,
        args: [address],
      });
      setStatus("mining");
      const receipt = await waitForTransactionReceipt(web3Config, { hash });
      if (receipt.status === "success" && receipt.contractAddress) {
        setWatcher(receipt.contractAddress);
        setStatus("success");
      } else {
        setStatus("error");
        setError("deployment reverted");
      }
    } catch (e) {
      setStatus("error");
      setError(e instanceof Error ? e.message.split("\n")[0] : String(e));
    }
  };

  const busy = status === "pending" || status === "mining";

  if (watcher && status === "idle") {
    return (
      <div className="deploy-status">
        <span className="dim">watcher already saved; continue below</span>
        <button type="button" className="text-toggle" onClick={onClick}>
          advanced: deploy another watcher
        </button>
      </div>
    );
  }

  return (
    <div className="deploy-status">
      <Button onClick={onClick} disabled={busy}>
        {LABELS[status]}
      </Button>
      {error && (
        <span className="dim">
          {"error: "}
          {error}
        </span>
      )}
    </div>
  );
};
