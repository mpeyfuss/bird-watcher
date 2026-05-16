import type { Abi, Hex } from "viem";
import artifact from "./BirdWatcher.json";

export const birdWatcherAbi = artifact.abi as Abi;
export const birdWatcherBytecode = artifact.bytecode.object as Hex;
