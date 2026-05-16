# Bird Watcher

An automated bird observation contract for the onchain Birds project by [Jules](https://birds.app).

`BirdWatcher` scans the active sanctuaries, finds the first observable bird that has not reached this contract's configured observation limit, and exposes the result through a Chainlink Automation-compatible `checkUpkeep` / `performUpkeep` flow.

The included web app is an open-source frontend for helping people deploy and configure their own `BirdWatcher`.

Disclaimer: these contracts and the web app are deployed as-is. Review the code and use them at your own risk.

## Past Deployments

| Contract | Address | Notes |
| --- | --- | --- |
| `BirdWatcher` | `0x7e5e5a30fbEe1Ef3EA75f28cBF80527715a41D14` | Latest deployment |
| `BirdWatcher` | `0xD6a421f752ada327D00606A0f2D8bFe6AcfE2476` | Original deployment |

The contract integrates with these deployed Birds contracts:

| Contract | Address |
| --- | --- |
| `BIRDS` | `0x75de5Bc35248026faBcb2382Cf322Bc79dFD1A8C` |
| `BIRD_OBSERVATIONS` | `0xCF24e99e8706fF84F90e92e73aD644a1e17bEB45` |

## How It Works

1. `checkUpkeep` verifies that birds have not departed and the observer migration cooldown has elapsed.
2. It scans sanctuary IDs `1` through `10`.
3. It selects the first occupied sanctuary whose current bird has been observed fewer than `observationLimit` times by this watcher.
4. `performUpkeep` can only be called by the configured Automation forwarder.
5. `performUpkeep` checks the transaction gas price, increments the observation count, pays the current observation fee, and calls `BirdObservations.observe`.

Default runtime settings:

| Setting | Default |
| --- | --- |
| `maxFee` | `0.001 ether` |
| `maxGasPrice` | `2 gwei` |
| `observationLimit` | `1` |
| `OBSERVER_MIGRATION_COOLDOWN` | `10 seconds` |
| `MAX_SANCTUARIES` | `10` |

## Owner Controls

The owner can:

- Set the Chainlink Automation forwarder with `setForwarder`.
- Tune the maximum accepted observation fee with `setMaxFee`.
- Tune the maximum accepted gas price with `setMaxGasPrice`.
- Adjust per-bird observation limits with `setObservationLimit`.
- Withdraw ETH, ERC-20, ERC-721, and ERC-1155 tokens held by the watcher.

## Development

This project uses Foundry and Soldeer.

Install dependencies:

```sh
make install
```

Build:

```sh
make build
```

Run tests:

```sh
make test-std
```

Run quick fuzz tests:

```sh
make test-quick
```

Format:

```sh
make fmt
```

## Mainnet Fork Simulation

`script/SimulateMainnet.s.sol` can inspect live Birds state and simulate `checkUpkeep` / `performUpkeep` on a fork.

Set an RPC URL in `.env`:

```sh
ETH_RPC_URL=<mainnet_rpc_url>
```

Simulate the deployed watcher:

```sh
BIRD_WATCHER_ADDRESS=0x7e5e5a30fbEe1Ef3EA75f28cBF80527715a41D14 \
forge script script/SimulateMainnet.s.sol:SimulateMainnet --fork-url "$ETH_RPC_URL" -vvv
```

Optional simulation parameters:

| Variable | Default |
| --- | --- |
| `SIM_FUNDING_WEI` | `0.01 ether` |
| `SIM_GAS_PRICE_WEI` | `1 gwei` |

If `BIRD_WATCHER_ADDRESS` is omitted, the script deploys a local watcher on the fork and configures a local forwarder for simulation.

## License

MIT
