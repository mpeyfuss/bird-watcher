// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std-1.14.0/Test.sol";
import {BirdWatcher} from "../src/BirdWatcher.sol";
import {AutomationBase} from "../src/lib/AutomationBase.sol";
import {AutomationCompatibleInterface} from "../src/lib/AutomationCompatibleInterface.sol";
import {IBirds, IBirdsObservations} from "../src/lib/BirdsInterfaces.sol";
import {ERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin-contracts-5.6.1/token/ERC721/ERC721.sol";
import {IERC1155Receiver, IERC165} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin-contracts-5.6.1/access/Ownable.sol";

contract MockBirds is IBirds {
    bool public birdsDeparted;
    uint64 public epochTimestamp;
    mapping(uint8 sanctuaryId => bool occupied) public occupied;
    mapping(uint8 sanctuaryId => uint8 birdId) public birdIds;

    function setBirdsDeparted(bool birdsDeparted_) external {
        birdsDeparted = birdsDeparted_;
    }

    function setEpochTimestamp(uint64 epochTimestamp_) external {
        epochTimestamp = epochTimestamp_;
    }

    function setSanctuaryState(uint8 sanctuaryId, bool occupied_, uint8 birdId) external {
        occupied[sanctuaryId] = occupied_;
        birdIds[sanctuaryId] = birdId;
    }

    function getSanctuaryState(uint8 sanctuaryId) external view returns (bool occupied_, uint8 birdId) {
        occupied_ = occupied[sanctuaryId];
        birdId = birdIds[sanctuaryId];
    }
}

contract MockBirdObservations is IBirdsObservations {
    uint256 public observationFee;
    uint8 public lastSanctuaryId;
    uint8 public lastBirdId;
    uint256 public lastMaxFeeWei;
    uint256 public lastValue;
    uint256 public observeCalls;

    function setObservationFee(uint256 observationFee_) external {
        observationFee = observationFee_;
    }

    function observe(uint8 sanctuaryId, uint8 expectedBirdId, uint256 maxFeeWei) external payable {
        lastSanctuaryId = sanctuaryId;
        lastBirdId = expectedBirdId;
        lastMaxFeeWei = maxFeeWei;
        lastValue = msg.value;
        ++observeCalls;
    }
}

contract RejectEth {
    receive() external payable {
        revert("reject eth");
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

contract MockERC721 is ERC721 {
    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract BirdWatcherTest is Test {
    address private constant OWNER = address(0xABCD);
    address private constant FORWARDER = address(0xF00D);
    address private constant SIMULATED_ORIGIN = address(0x1111111111111111111111111111111111111111);
    uint8 private constant MAX_BIRD_ID = 100;

    BirdWatcher private watcher;
    MockBirds private birds;
    MockBirdObservations private birdObservations;

    function setUp() public {
        vm.warp(1_000);
        watcher = new BirdWatcher(OWNER);

        address birdsAddress = watcher.BIRDS();
        address observationsAddress = watcher.BIRD_OBSERVATIONS();

        vm.etch(birdsAddress, address(new MockBirds()).code);
        vm.etch(observationsAddress, address(new MockBirdObservations()).code);

        birds = MockBirds(birdsAddress);
        birdObservations = MockBirdObservations(observationsAddress);

        birds.setEpochTimestamp(uint64(block.timestamp - watcher.OBSERVER_MIGRATION_COOLDOWN()));
        birdObservations.setObservationFee(0.0001 ether);

        vm.prank(OWNER);
        watcher.setForwarder(FORWARDER);
        vm.deal(address(watcher), 1 ether);
    }

    function testCheckUpkeepRevertsWhenCalledOutsideSimulation() public {
        vm.expectRevert(AutomationBase.OnlySimulatedBackend.selector);
        watcher.checkUpkeep("");
    }

    function testDefaultsToTwoGweiMaxGasPrice() public view {
        assertEq(watcher.maxGasPrice(), 2 gwei);
    }

    function testCheckUpkeepReturnsFalseWhenBirdsDeparted() public {
        birds.setBirdsDeparted(true);
        birds.setSanctuaryState(1, true, 42);

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();

        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testCheckUpkeepReturnsFalseDuringMigrationCooldown() public {
        birds.setSanctuaryState(1, true, 42);
        birds.setEpochTimestamp(uint64(block.timestamp - watcher.OBSERVER_MIGRATION_COOLDOWN() + 1));

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();

        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testCheckUpkeepReturnsFalseWhenBalanceIsBelowObservationFee() public {
        birds.setSanctuaryState(1, true, 42);
        vm.deal(address(watcher), birdObservations.observationFee() - 1);

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();

        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testCheckUpkeepReturnsFalseWhenNoSanctuaryIsOccupied() public {
        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();
        BirdWatcher.Observation memory observation = abi.decode(performData, (BirdWatcher.Observation));

        assertFalse(upkeepNeeded);
        assertEq(observation.sanctuaryId, 0);
        assertEq(observation.birdId, 0);
    }

    function testCheckUpkeepReturnsFirstEligibleObservation() public {
        birds.setSanctuaryState(2, true, 7);
        birds.setSanctuaryState(4, true, 9);

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();
        BirdWatcher.Observation memory observation = abi.decode(performData, (BirdWatcher.Observation));

        assertTrue(upkeepNeeded);
        assertEq(observation.sanctuaryId, 2);
        assertEq(observation.birdId, 7);
    }

    function testCheckUpkeepHandlesMaxBirdId() public {
        birds.setSanctuaryState(1, true, MAX_BIRD_ID);

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();
        BirdWatcher.Observation memory observation = abi.decode(performData, (BirdWatcher.Observation));

        assertTrue(upkeepNeeded);
        assertEq(observation.sanctuaryId, 1);
        assertEq(observation.birdId, MAX_BIRD_ID);
    }

    function testCheckUpkeepSkipsObservationAtLimit() public {
        birds.setSanctuaryState(1, true, 7);
        birds.setSanctuaryState(2, true, 8);
        _performObservation(1, 7);

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();
        BirdWatcher.Observation memory observation = abi.decode(performData, (BirdWatcher.Observation));

        assertTrue(upkeepNeeded);
        assertEq(observation.sanctuaryId, 2);
        assertEq(observation.birdId, 8);
    }

    function testCheckUpkeepAllowsAdditionalObservationWhenLimitIncreases() public {
        birds.setSanctuaryState(1, true, 7);
        birds.setSanctuaryState(2, true, 8);
        _performObservation(1, 7);

        vm.prank(OWNER);
        watcher.setObservationLimit(2);

        (bool upkeepNeeded, bytes memory performData) = _checkUpkeep();
        BirdWatcher.Observation memory observation = abi.decode(performData, (BirdWatcher.Observation));

        assertTrue(upkeepNeeded);
        assertEq(observation.sanctuaryId, 1);
        assertEq(observation.birdId, 7);
    }

    function testPerformUpkeepRevertsUnlessCalledByForwarder() public {
        bytes memory performData = _performData(1, 7);

        vm.expectRevert(BirdWatcher.NotForwarder.selector);
        watcher.performUpkeep(performData);
    }

    function testPerformUpkeepRevertsWhenGasPriceIsTooHigh() public {
        bytes memory performData = _performData(1, 7);

        vm.txGasPrice(watcher.maxGasPrice() + 1);
        vm.prank(FORWARDER);
        vm.expectRevert(BirdWatcher.TooExpensive.selector);
        watcher.performUpkeep(performData);
    }

    function testPerformUpkeepObservesBirdAndUpdatesCount() public {
        uint8 sanctuaryId = 3;
        uint8 birdId = 11;
        uint256 fee = birdObservations.observationFee();

        vm.expectEmit(true, true, false, false, address(watcher));
        emit BirdWatcher.Observed(sanctuaryId, birdId);

        _performObservation(sanctuaryId, birdId);

        assertEq(watcher.observationCounts(sanctuaryId, birdId), 1);
        assertEq(birdObservations.observeCalls(), 1);
        assertEq(birdObservations.lastSanctuaryId(), sanctuaryId);
        assertEq(birdObservations.lastBirdId(), birdId);
        assertEq(birdObservations.lastMaxFeeWei(), watcher.maxFee());
        assertEq(birdObservations.lastValue(), fee);
    }

    function testOnlyOwnerCanConfigureAutomationSettings() public {
        vm.expectRevert();
        watcher.setForwarder(address(1));
        vm.expectRevert();
        watcher.setMaxFee(0.002 ether);
        vm.expectRevert();
        watcher.setMaxGasPrice(7 gwei);
        vm.expectRevert();
        watcher.setObservationLimit(3);

        vm.startPrank(OWNER);
        watcher.setForwarder(address(1));
        watcher.setMaxFee(0.002 ether);
        watcher.setMaxGasPrice(7 gwei);
        watcher.setObservationLimit(3);
        vm.stopPrank();

        assertEq(watcher.forwarder(), address(1));
        assertEq(watcher.maxFee(), 0.002 ether);
        assertEq(watcher.maxGasPrice(), 7 gwei);
        assertEq(watcher.observationLimit(), 3);
    }

    function testWithdrawEthTransfersFunds() public {
        address recipient = address(0xBEEF);

        vm.prank(OWNER);
        watcher.withdrawEth(recipient, 0.25 ether);

        assertEq(recipient.balance, 0.25 ether);
        assertEq(address(watcher).balance, 0.75 ether);
    }

    function testWithdrawEthRevertsWhenTransferFails() public {
        RejectEth recipient = new RejectEth();

        vm.prank(OWNER);
        vm.expectRevert(BirdWatcher.EthTransferFailed.selector);
        watcher.withdrawEth(address(recipient), 1 wei);
    }

    function testWithdrawERC20TransfersTokens() public {
        MockERC20 token = new MockERC20();
        address recipient = address(0xBEEF);

        token.mint(address(watcher), 100 ether);

        vm.prank(OWNER);
        watcher.withdrawERC20(address(token), recipient, 40 ether);

        assertEq(token.balanceOf(recipient), 40 ether);
        assertEq(token.balanceOf(address(watcher)), 60 ether);
    }

    function testWithdrawERC20RevertsUnlessOwner() public {
        MockERC20 token = new MockERC20();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        watcher.withdrawERC20(address(token), address(0xBEEF), 1);
    }

    function testWithdrawERC721TransfersToken() public {
        MockERC721 nft = new MockERC721();
        address recipient = address(0xBEEF);
        uint256 tokenId = 42;

        nft.mint(address(watcher), tokenId);

        vm.prank(OWNER);
        watcher.withdrawERC721(address(nft), recipient, tokenId);

        assertEq(nft.ownerOf(tokenId), recipient);
        assertEq(nft.balanceOf(address(watcher)), 0);
        assertEq(nft.balanceOf(recipient), 1);
    }

    function testWithdrawERC721RevertsUnlessOwner() public {
        MockERC721 nft = new MockERC721();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        watcher.withdrawERC721(address(nft), address(0xBEEF), 1);
    }

    function testSupportsAutomationAndReceiverInterfaces() public view {
        assertTrue(watcher.supportsInterface(type(IERC165).interfaceId));
        assertTrue(watcher.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertTrue(watcher.supportsInterface(type(AutomationCompatibleInterface).interfaceId));
        assertFalse(watcher.supportsInterface(0xffffffff));
    }

    function _checkUpkeep() private returns (bool upkeepNeeded, bytes memory performData) {
        vm.prank(address(this), SIMULATED_ORIGIN);
        (upkeepNeeded, performData) = watcher.checkUpkeep("");
    }

    function _performObservation(uint8 sanctuaryId, uint8 birdId) private {
        vm.prank(FORWARDER);
        watcher.performUpkeep(_performData(sanctuaryId, birdId));
    }

    function _performData(uint8 sanctuaryId, uint8 birdId) private pure returns (bytes memory) {
        return abi.encode(BirdWatcher.Observation({sanctuaryId: sanctuaryId, birdId: birdId}));
    }
}
