import { useCallback, useSyncExternalStore } from "react";
import { useAccount } from "wagmi";
import { isAddress, type Address } from "viem";

const STORAGE_KEY = "birdwatcher:watcher-by-owner";

type Store = Record<string, Address>;
type Listener = () => void;

const listeners = new Set<Listener>();

function emitChange() {
  for (const listener of listeners) {
    listener();
  }
}

function subscribe(listener: Listener) {
  listeners.add(listener);
  const onStorage = (event: StorageEvent) => {
    if (event.key === STORAGE_KEY) listener();
  };
  window.addEventListener("storage", onStorage);

  return () => {
    listeners.delete(listener);
    window.removeEventListener("storage", onStorage);
  };
}

function readStore(): Store {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Store) : {};
  } catch {
    return {};
  }
}

function writeStore(store: Store) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(store));
  emitChange();
}

export function useWatcherAddress() {
  const { address: owner } = useAccount();
  const ownerKey = owner?.toLowerCase();
  const watcher = useSyncExternalStore(
    subscribe,
    () => (ownerKey ? readStore()[ownerKey] : undefined),
    () => undefined,
  );

  const setWatcher = useCallback(
    (value: string | undefined) => {
      if (!ownerKey) return;
      const store = readStore();
      if (value && isAddress(value)) {
        store[ownerKey] = value;
        writeStore(store);
      } else {
        delete store[ownerKey];
        writeStore(store);
      }
    },
    [ownerKey],
  );

  return { watcher, setWatcher, hasOwner: !!owner };
}
