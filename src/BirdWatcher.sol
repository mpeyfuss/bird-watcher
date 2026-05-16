// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/*░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░                                                                                              ░░
░░  ██████╗ ██╗██████╗ ██████╗     ██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗███████╗██████╗   ░░
░░  ██╔══██╗██║██╔══██╗██╔══██╗    ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║██╔════╝██╔══██╗  ░░
░░  ██████╔╝██║██████╔╝██║  ██║    ██║ █╗ ██║███████║   ██║   ██║     ███████║█████╗  ██████╔╝  ░░
░░  ██╔══██╗██║██╔══██╗██║  ██║    ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║██╔══╝  ██╔══██╗  ░░
░░  ██████╔╝██║██║  ██║██████╔╝    ╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║███████╗██║  ██║  ░░
░░  ╚═════╝ ╚═╝╚═╝  ╚═╝╚═════╝      ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  ░░
░░                                                                                              ░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░*/

import {AutomationBase} from "./lib/AutomationBase.sol";
import {AutomationCompatibleInterface} from "./lib/AutomationCompatibleInterface.sol";
import {IBirds, IBirdsObservations} from "./lib/BirdsInterfaces.sol";
import {IERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.6.1/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver, IERC165} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts-5.6.1/access/Ownable.sol";

/// @title BirdWatcher
/// @notice Chainlink automation compatible interface for observing birds
/// @author mpeyfuss
contract BirdWatcher is Ownable, AutomationBase, AutomationCompatibleInterface, IERC721Receiver, IERC1155Receiver {
    /////////////////////////////////////////////////////////////////////
    // TYPES
    /////////////////////////////////////////////////////////////////////

    using SafeERC20 for IERC20;

    struct Observation {
        uint8 sanctuaryId;
        uint8 birdId;
    }

    /////////////////////////////////////////////////////////////////////
    // STORAGE
    /////////////////////////////////////////////////////////////////////

    uint256 public constant OBSERVER_MIGRATION_COOLDOWN = 10;
    uint256 public constant MAX_SANCTUARIES = 10;
    address public constant BIRDS = 0x75de5Bc35248026faBcb2382Cf322Bc79dFD1A8C;
    address public constant BIRD_OBSERVATIONS = 0xCF24e99e8706fF84F90e92e73aD644a1e17bEB45;

    address public forwarder;
    uint256 public maxFee = 0.001 ether;
    uint256 public maxGasPrice = 2 gwei;
    uint256 public observationLimit = 1;
    mapping(uint8 sanctuaryId => mapping(uint8 birdId => uint256)) public observationCounts;

    /////////////////////////////////////////////////////////////////////
    // EVENTS
    /////////////////////////////////////////////////////////////////////

    event Observed(uint8 indexed sanctuaryId, uint8 indexed birdId);

    /////////////////////////////////////////////////////////////////////
    // ERRORS
    /////////////////////////////////////////////////////////////////////

    error ArrayLengthMismatch();
    error EthTransferFailed();
    error NotForwarder();
    error TooExpensive();

    /////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    /////////////////////////////////////////////////////////////////////

    constructor(address owner_) Ownable(owner_) {}

    /////////////////////////////////////////////////////////////////////
    // RECEIVE
    /////////////////////////////////////////////////////////////////////

    receive() external payable {}

    /////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////

    function setForwarder(address forwarder_) external onlyOwner {
        forwarder = forwarder_;
    }

    function setMaxFee(uint256 maxFee_) external onlyOwner {
        maxFee = maxFee_;
    }

    function setMaxGasPrice(uint256 maxGasPrice_) external onlyOwner {
        maxGasPrice = maxGasPrice_;
    }

    function setObservationLimit(uint256 limit) external onlyOwner {
        observationLimit = limit;
    }

    function withdrawERC1155(address nftAddress, address recipient, uint256[] calldata ids, uint256[] calldata amounts)
        external
        onlyOwner
    {
        if (ids.length != amounts.length) revert ArrayLengthMismatch();
        IERC1155(nftAddress).safeBatchTransferFrom(address(this), recipient, ids, amounts, "");
    }

    function withdrawERC721(address nftAddress, address recipient, uint256 tokenId) external onlyOwner {
        IERC721(nftAddress).safeTransferFrom(address(this), recipient, tokenId);
    }

    function withdrawERC20(address tokenAddress, address recipient, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }

    function withdrawEth(address recipient, uint256 amount) external onlyOwner {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert EthTransferFailed();
    }

    /////////////////////////////////////////////////////////////////////
    // AUTOMATION
    /////////////////////////////////////////////////////////////////////

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        cannotExecute
        returns (bool upkeepNeeded, bytes memory performData)
    {
        IBirds birds = IBirds(BIRDS);
        if (birds.birdsDeparted()) return (false, "");
        if (block.timestamp < birds.epochTimestamp() + OBSERVER_MIGRATION_COOLDOWN) return (false, "");
        if (address(this).balance < IBirdsObservations(BIRD_OBSERVATIONS).observationFee()) return (false, "");

        (bool observationPossible, Observation memory observation) = _getObservation();
        return (observationPossible, abi.encode(observation));
    }

    function performUpkeep(bytes calldata performData) external {
        if (msg.sender != forwarder) revert NotForwarder();
        if (tx.gasprice > maxGasPrice) revert TooExpensive();

        Observation memory observation = abi.decode(performData, (Observation));
        ++observationCounts[observation.sanctuaryId][observation.birdId];

        IBirdsObservations birdObservations = IBirdsObservations(BIRD_OBSERVATIONS);
        uint256 fee = birdObservations.observationFee();
        birdObservations.observe{value: fee}(observation.sanctuaryId, observation.birdId, maxFee);

        emit Observed(observation.sanctuaryId, observation.birdId);
    }

    /////////////////////////////////////////////////////////////////////
    // IERC721Receiver
    /////////////////////////////////////////////////////////////////////

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /////////////////////////////////////////////////////////////////////
    // IERC1155Receiver
    /////////////////////////////////////////////////////////////////////

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /////////////////////////////////////////////////////////////////////
    // IERC165
    /////////////////////////////////////////////////////////////////////

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId
            || interfaceId == type(AutomationCompatibleInterface).interfaceId;
    }

    /////////////////////////////////////////////////////////////////////
    // HELPERS
    /////////////////////////////////////////////////////////////////////

    function _getObservation() internal view returns (bool observationPossible, Observation memory observation) {
        IBirds birds = IBirds(BIRDS);
        uint256 limit = observationLimit;
        for (uint8 i = 0; i < MAX_SANCTUARIES; ++i) {
            uint8 sanctuaryId = i + 1;
            (bool occupied, uint8 birdId) = birds.getSanctuaryState(sanctuaryId);
            if (occupied && observationCounts[sanctuaryId][birdId] < limit) {
                observation = Observation({sanctuaryId: sanctuaryId, birdId: birdId});
                observationPossible = true;
                break;
            }
        }
    }
}
