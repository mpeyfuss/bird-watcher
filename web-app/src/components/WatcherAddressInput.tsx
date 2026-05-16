import { useState } from "react";
import { isAddress } from "viem";
import { useWatcherAddress } from "../hooks/useWatcherAddress";
import { Button } from "./Button";

export const WatcherAddressInput = () => {
  const { watcher, setWatcher, hasOwner } = useWatcherAddress();
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [copyStatus, setCopyStatus] = useState<"idle" | "copied" | "error">(
    "idle",
  );

  const copyWatcher = async () => {
    if (!watcher) return;
    try {
      await navigator.clipboard.writeText(watcher);
      setCopyStatus("copied");
      window.setTimeout(() => setCopyStatus("idle"), 1600);
    } catch {
      setCopyStatus("error");
      window.setTimeout(() => setCopyStatus("idle"), 2400);
    }
  };

  if (!hasOwner) {
    return (
      <div className="watcher-panel dim">
        WATCHER: connect a wallet to deploy or load your watcher
      </div>
    );
  }

  return (
    <div className="watcher-panel">
      <div className="watcher-status">
        <span className="watcher-label">WATCHER:</span>
        {watcher ? (
          <Button href={`https://etherscan.io/address/${watcher}`} external>
            {watcher}
          </Button>
        ) : (
          <span className="dim">none saved yet</span>
        )}
        {watcher && (
          <button type="button" className="copy-button" onClick={copyWatcher}>
            [{" "}
            {copyStatus === "copied"
              ? "copied"
              : copyStatus === "error"
                ? "failed"
                : "copy"}{" "}
            ]
          </button>
        )}
      </div>
      <button
        type="button"
        className="text-toggle advanced-toggle"
        onClick={() => setShowAdvanced((show) => !show)}
      >
        advanced:{" "}
        {showAdvanced ? "hide address tools" : "use a different watcher"}
      </button>
      {showAdvanced && (
        <div className="advanced-tools">
          <WatcherAddressEditor
            key={watcher ?? "empty"}
            watcher={watcher}
            setWatcher={setWatcher}
          />
        </div>
      )}
    </div>
  );
};

function WatcherAddressEditor({
  watcher,
  setWatcher,
}: {
  watcher: string | undefined;
  setWatcher: (value: string | undefined) => void;
}) {
  const [draft, setDraft] = useState(watcher ?? "");
  const valid = draft === "" || isAddress(draft);
  const changed = draft !== (watcher ?? "");

  return (
    <div className="watcher-input">
      <span className="watcher-label">ADDRESS:</span>
      <input
        className="field"
        spellCheck={false}
        autoComplete="off"
        placeholder="0x..."
        value={draft}
        onChange={(e) => setDraft(e.target.value.trim())}
        size={44}
      />{" "}
      <Button
        onClick={() => setWatcher(draft || undefined)}
        disabled={!valid || !changed}
      >
        {draft === "" ? "clear" : "save"}
      </Button>
    </div>
  );
}
