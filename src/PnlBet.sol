// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interface/L1Read.sol";

contract PnlBet is Initializable, ReentrancyGuard {
    address public immutable factory;
    address public targetUser;
    uint32 public perpId;
    uint256 public endTime;

    uint256 public profitablePoolBalance;
    uint256 public unprofitablePoolBalance;

    int256 public lastTrackedPnl;
    uint256 public lastTrackedTimestamp;

    // Configurable addresses for dependency injection (for testing)
    address public immutable positionReader;
    address public immutable markPxReader;

    mapping(address => uint256) public profitableBets;
    mapping(address => uint256) public unprofitableBets;

    enum Outcome {
        Undecided,
        Profitable,
        Unprofitable
    }

    Outcome public outcome;
    bool public isSettled;

    event BetPlaced(address indexed bettor, bool isBettingOnProfit, uint256 amount);
    event BetSettled(Outcome outcome, uint256 totalPool);
    event WinningsClaimed(address indexed winner, uint256 amount);
    event PnlSnapshotted(int256 pnl, uint256 timestamp);

    error BettingClosed();
    error BetNotOver();
    error AlreadySettled();
    error BetNotSettled();
    error NoWinnings();
    error TransferFailed();
    error PositionAlreadyClosed();

    modifier onlyBeforeEnd() {
        if (block.timestamp >= endTime) revert BettingClosed();
        _;
    }

    modifier onlyAfterEnd() {
        if (block.timestamp < endTime) revert BetNotOver();
        _;
    }

    modifier onlyUnsettled() {
        if (isSettled) revert AlreadySettled();
        _;
    }

    modifier onlySettled() {
        if (!isSettled) revert BetNotSettled();
        _;
    }

    constructor(address _positionReader, address _markPxReader) {
        factory = msg.sender;
        positionReader = _positionReader != address(0) ? _positionReader : 0x0000000000000000000000000000000000000800;
        markPxReader = _markPxReader != address(0) ? _markPxReader : 0x0000000000000000000000000000000000000806;
        _disableInitializers();
    }

    function initialize(address _targetUser, uint32 _perpId, uint256 _endTime) external initializer {
        targetUser = _targetUser;
        perpId = _perpId;
        endTime = _endTime;
        outcome = Outcome.Undecided;
    }

    function placeBet(bool isBettingOnProfit) external payable onlyBeforeEnd nonReentrant {
        require(msg.value > 0, "Must bet non-zero amount");

        if (isBettingOnProfit) {
            profitableBets[msg.sender] += msg.value;
            profitablePoolBalance += msg.value;
        } else {
            unprofitableBets[msg.sender] += msg.value;
            unprofitablePoolBalance += msg.value;
        }

        emit BetPlaced(msg.sender, isBettingOnProfit, msg.value);
    }

    function snapshotPnl() external onlyBeforeEnd onlyUnsettled {
        (int256 pnl, bool isClosed) = _calculatePnl();
        if (isClosed) revert PositionAlreadyClosed();

        lastTrackedPnl = pnl;
        lastTrackedTimestamp = block.timestamp;
        emit PnlSnapshotted(pnl, block.timestamp);
    }

    function settle() external onlyAfterEnd onlyUnsettled nonReentrant {
        L1Read reader = L1Read(positionReader);
        L1Read.Position memory pos = reader.position(targetUser, uint16(perpId));

        // If position is closed at settlement, use the last tracked PNL
        if (pos.szi == 0) {
            // If there was a snapshot, use it
            if (lastTrackedTimestamp > 0) {
                if (lastTrackedPnl > 0) {
                    outcome = Outcome.Profitable;
                } else {
                    outcome = Outcome.Unprofitable;
                }
            } else {
                // If no snapshot, it's a loss
                outcome = Outcome.Unprofitable;
            }
        } else {
            // If position is still open, calculate final PNL
            (int256 pnl,) = _calculatePnl();
            if (pnl > 0) {
                outcome = Outcome.Profitable;
            } else {
                outcome = Outcome.Unprofitable;
            }
        }

        isSettled = true;
        uint256 totalPool = profitablePoolBalance + unprofitablePoolBalance;
        emit BetSettled(outcome, totalPool);
    }

    function claimWinnings() external onlySettled nonReentrant {
        uint256 userBet;
        uint256 winningPool;
        uint256 totalPool = profitablePoolBalance + unprofitablePoolBalance;
        address user = msg.sender;

        if (outcome == Outcome.Profitable) {
            userBet = profitableBets[user];
            winningPool = profitablePoolBalance;
            profitableBets[user] = 0; // Prevent re-entrancy and double claims
        } else {
            // Outcome is Unprofitable
            userBet = unprofitableBets[user];
            winningPool = unprofitablePoolBalance;
            unprofitableBets[user] = 0; // Prevent re-entrancy and double claims
        }

        if (userBet == 0) revert NoWinnings();

        uint256 winnings;
        // Edge Case: If winning pool is 0, refund everyone their original bet
        if (winningPool == 0) {
            winnings = userBet;
        } else {
            // Standard case: Calculate proportional winnings
            winnings = (userBet * totalPool) / winningPool;
        }

        (bool success,) = payable(user).call{value: winnings}("");
        if (!success) revert TransferFailed();

        emit WinningsClaimed(user, winnings);
    }

    function _calculatePnl() internal view returns (int256, bool) {
        L1Read reader = L1Read(positionReader);
        L1Read.Position memory pos = reader.position(targetUser, uint16(perpId));

        if (pos.szi == 0) {
            return (0, true);
        }

        uint64 currentMarkPrice = L1Read(markPxReader).markPx(perpId);
        uint64 entryPrice = pos.entryNtl / uint64(abs(pos.szi));
        int256 pnl = (int256(uint256(currentMarkPrice)) - int256(uint256(entryPrice))) * pos.szi;
        return (pnl, false);
    }

    // --- ADDED: Helper function for absolute value ---
    function abs(int256 x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function getTotalPool() external view returns (uint256) {
        return profitablePoolBalance + unprofitablePoolBalance;
    }

    function getUserBet(address user) external view returns (uint256 profitBet, uint256 lossBet) {
        return (profitableBets[user], unprofitableBets[user]);
    }
}
