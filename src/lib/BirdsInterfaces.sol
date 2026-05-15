// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBirds {
    function getSanctuaryState(uint8 sanctuaryId) external view returns (bool occupied, uint8 birdId);
    function epochTimestamp() external view returns (uint64);
    function birdsDeparted() external view returns (bool);
}

interface IBirdsObservations {
    function observationFee() external view returns (uint256);
    function observe(uint8 sanctuaryId, uint8 expectedBirdId, uint256 maxFeeWei) external payable;
}
