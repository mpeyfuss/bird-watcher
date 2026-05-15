// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std-1.14.0/Script.sol";
import {BirdWatcher} from "../src/BirdWatcher.sol";
import {IBirds, IBirdsObservations} from "../src/lib/BirdsInterfaces.sol";

contract SimulateMainnet is Script {
    address private constant LOCAL_OWNER = address(0xB0B);
    address private constant LOCAL_FORWARDER = address(0xF00D);
    address private constant SIMULATED_CALLER = address(0xCA11);
    address private constant SIMULATED_ORIGIN = address(0x1111111111111111111111111111111111111111);

    function run() external {
        BirdWatcher watcher = _getOrDeployWatcher();
        IBirds birds = IBirds(watcher.BIRDS());
        IBirdsObservations birdObservations = IBirdsObservations(watcher.BIRD_OBSERVATIONS());

        console2.log("=== Fork context ===");
        console2.log("chain id", block.chainid);
        console2.log("block number", block.number);
        console2.log("block timestamp", block.timestamp);
        console2.log("");

        console2.log("=== Contracts ===");
        console2.log("BirdWatcher", address(watcher));
        console2.log("Birds", watcher.BIRDS());
        console2.log("BirdObservations", watcher.BIRD_OBSERVATIONS());
        console2.log("owner", watcher.owner());
        console2.log("forwarder", watcher.forwarder());
        console2.log("watcher balance", address(watcher).balance);
        console2.log("maxFee", watcher.maxFee());
        console2.log("maxGasPrice", watcher.maxGasPrice());
        console2.log("observationLimit", watcher.observationLimit());
        console2.log("");

        uint64 epochTimestamp = birds.epochTimestamp();
        uint256 cooldownEndsAt = uint256(epochTimestamp) + watcher.OBSERVER_MIGRATION_COOLDOWN();
        uint256 observationFee = birdObservations.observationFee();

        console2.log("=== Live Birds state ===");
        console2.log("birdsDeparted", birds.birdsDeparted());
        console2.log("epochTimestamp", epochTimestamp);
        console2.log("cooldownEndsAt", cooldownEndsAt);
        console2.log("cooldownOver", block.timestamp >= cooldownEndsAt);
        console2.log("observationFee", observationFee);
        console2.log("");

        console2.log("=== Sanctuary scan ===");
        for (uint8 sanctuaryId = 1; sanctuaryId <= watcher.MAX_SANCTUARIES(); ++sanctuaryId) {
            (bool occupied, uint8 birdId) = birds.getSanctuaryState(sanctuaryId);
            console2.log("sanctuary", sanctuaryId);
            console2.log("  occupied", occupied);
            console2.log("  birdId", birdId);
            console2.log("  watcher observation count", watcher.observationCounts(sanctuaryId, birdId));
        }
        console2.log("");

        console2.log("=== checkUpkeep simulation ===");
        vm.prank(SIMULATED_CALLER, SIMULATED_ORIGIN);
        (bool upkeepNeeded, bytes memory performData) = watcher.checkUpkeep("");
        console2.log("upkeepNeeded", upkeepNeeded);
        console2.log("performData length", performData.length);

        if (!upkeepNeeded) {
            console2.log("No performUpkeep simulation: checkUpkeep returned false.");
            return;
        }

        BirdWatcher.Observation memory observation = abi.decode(performData, (BirdWatcher.Observation));
        console2.log("selected sanctuaryId", observation.sanctuaryId);
        console2.log("selected birdId", observation.birdId);
        console2.log(
            "selected observation count before", watcher.observationCounts(observation.sanctuaryId, observation.birdId)
        );
        console2.log("");

        uint256 fundingWei = vm.envOr("SIM_FUNDING_WEI", uint256(0.01 ether));
        if (address(watcher).balance < observationFee) {
            vm.deal(address(watcher), fundingWei);
            console2.log("funded watcher on fork", fundingWei);
        }

        uint256 gasPriceWei = vm.envOr("SIM_GAS_PRICE_WEI", uint256(1 gwei));
        address forwarder = watcher.forwarder();
        require(forwarder != address(0), "forwarder is not set");

        console2.log("=== performUpkeep simulation ===");
        console2.log("perform caller", forwarder);
        console2.log("tx gas price", gasPriceWei);
        console2.log("watcher balance before", address(watcher).balance);

        uint256 gasUsed = _performUpkeep(watcher, forwarder, gasPriceWei, performData);

        console2.log("performUpkeep succeeded");
        console2.log("performUpkeep gas used", gasUsed);
        console2.log("estimated gas cost wei", gasUsed * gasPriceWei);
        console2.log("watcher balance after", address(watcher).balance);
        console2.log(
            "selected observation count after", watcher.observationCounts(observation.sanctuaryId, observation.birdId)
        );
    }

    function _getOrDeployWatcher() private returns (BirdWatcher watcher) {
        address watcherAddress = vm.envOr("BIRD_WATCHER_ADDRESS", address(0));
        if (watcherAddress != address(0)) {
            return BirdWatcher(payable(watcherAddress));
        }

        vm.startPrank(LOCAL_OWNER);
        watcher = new BirdWatcher(LOCAL_OWNER);
        watcher.setForwarder(LOCAL_FORWARDER);
        vm.stopPrank();
    }

    function _performUpkeep(BirdWatcher watcher, address forwarder, uint256 gasPriceWei, bytes memory performData)
        private
        returns (uint256 gasUsed)
    {
        vm.txGasPrice(gasPriceWei);
        vm.prank(forwarder);
        uint256 gasBefore = gasleft();
        watcher.performUpkeep(performData);
        gasUsed = gasBefore - gasleft();
    }
}
