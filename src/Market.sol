// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OutcomeToken.sol";
import "./MarketAMM.sol";
import "./interface/L1Read.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Market is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Configuration ---
    address public immutable USDC; // Address of the USDC ERC-20 token
    address public immutable targetUser;
    uint32 public immutable perpId;
    uint256 public immutable endTime;

    uint256 private constant USDC_DECIMALS = 6;
    uint256 private constant OUTCOME_TOKEN_DECIMALS = 18;
    uint256 private constant USDC_TO_OUTCOME_TOKEN_SCALAR = 10 ** (OUTCOME_TOKEN_DECIMALS - USDC_DECIMALS);

    // --- Deployed Contracts ---
    address public yesToken;
    address public noToken;
    address public amm;

    // --- Settlement ---
    enum Outcome {
        Undecided,
        Profitable,
        Unprofitable
    }

    Outcome public outcome;
    bool public isSettled;

    // --- Precompile Readers ---
    address public immutable positionReader;
    address public immutable markPxReader;

    // --- Position Commitment ---
    int64 public committedSzi;
    uint64 public committedEntryNtl;
    uint256 public commitmentTime;
    bool public positionCommitted;

    // --- PNL Snapshot ---
    int256 public lastTrackedPnl;
    uint256 public lastTrackedTimestamp;
    bool public positionWasClosed;

    event Minted(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);
    event Settled(Outcome outcome);
    event PositionCommitted(int64 szi, uint64 entryNtl, uint256 timestamp);
    event PositionChanged(int64 oldSzi, uint64 oldEntryNtl, int64 newSzi, uint64 newEntryNtl);
    event PositionClosed(uint256 timestamp, int256 finalPnl);

    error AlreadySettled();
    error NotSettled();
    error WrongToken();

    constructor(
        address _targetUser,
        uint32 _perpId,
        uint256 _endTime,
        address _usdcTokenAddress,
        address _positionReader,
        address _markPxReader
    ) {
        targetUser = _targetUser;
        perpId = _perpId;
        endTime = _endTime;
        USDC = _usdcTokenAddress;
        positionReader = _positionReader;
        markPxReader = _markPxReader;
        outcome = Outcome.Undecided;
    }

    function initialize(address _yesToken, address _noToken, address _amm) external {
        require(yesToken == address(0), "Already initialized");
        yesToken = _yesToken;
        noToken = _noToken;
        amm = _amm;
        
        // Capture initial position fingerprint
        _commitPosition();
    }

    function _commitPosition() internal {
        (bool success, bytes memory data) = positionReader.staticcall(
            abi.encode(targetUser, uint16(perpId))
        );
        require(success, "Position call failed during commitment");
        
        (int64 szi, uint64 entryNtl,,,) = abi.decode(data, (int64, uint64, int64, uint32, bool));
        require(szi != 0, "No position to commit to");
        
        committedSzi = szi;
        committedEntryNtl = entryNtl;
        commitmentTime = block.timestamp;
        positionCommitted = true;
        
        emit PositionCommitted(szi, entryNtl, block.timestamp);
    }

    function mintCompleteSet(uint256 usdcAmount) external nonReentrant {
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), usdcAmount);
        uint256 outcomeTokenAmount = usdcAmount * USDC_TO_OUTCOME_TOKEN_SCALAR;
        OutcomeToken(yesToken).mint(msg.sender, outcomeTokenAmount);
        OutcomeToken(noToken).mint(msg.sender, outcomeTokenAmount);
        emit Minted(msg.sender, usdcAmount);
    }

    function redeemCompleteSet(uint256 amount) external nonReentrant {
        OutcomeToken(yesToken).burn(msg.sender, amount);
        OutcomeToken(noToken).burn(msg.sender, amount);
        uint256 usdcAmount = amount / USDC_TO_OUTCOME_TOKEN_SCALAR;
        IERC20(USDC).safeTransfer(msg.sender, usdcAmount);
        emit Redeemed(msg.sender, usdcAmount);
    }

    function buyYesTokens(uint256 usdcAmountToSpend, uint256 minYesTokensToReceive) external nonReentrant {
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), usdcAmountToSpend);
        uint256 outcomeTokenAmount = usdcAmountToSpend * USDC_TO_OUTCOME_TOKEN_SCALAR;
        OutcomeToken(yesToken).mint(address(this), outcomeTokenAmount);
        OutcomeToken(noToken).mint(address(this), outcomeTokenAmount);

        IERC20(noToken).approve(address(amm), outcomeTokenAmount);

        uint256 minYesTokensToReceiveScaled = minYesTokensToReceive;

        uint256 minSwapAmountOut = 0;
        if (minYesTokensToReceiveScaled > outcomeTokenAmount) {
            minSwapAmountOut = minYesTokensToReceiveScaled - outcomeTokenAmount;
        }

        uint256 swappedYesTokens = MarketAMM(amm).swap(noToken, outcomeTokenAmount, minSwapAmountOut, address(this));

        uint256 totalYesTokens = outcomeTokenAmount + swappedYesTokens;
        if (totalYesTokens < minYesTokensToReceiveScaled) revert(); // InsufficientOutput

        IERC20(yesToken).safeTransfer(msg.sender, totalYesTokens);
    }

    function buyNoTokens(uint256 usdcAmountToSpend, uint256 minNoTokensToReceive) external nonReentrant {
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), usdcAmountToSpend);
        uint256 outcomeTokenAmount = usdcAmountToSpend * USDC_TO_OUTCOME_TOKEN_SCALAR;
        OutcomeToken(yesToken).mint(address(this), outcomeTokenAmount);
        OutcomeToken(noToken).mint(address(this), outcomeTokenAmount);

        IERC20(yesToken).approve(address(amm), outcomeTokenAmount);

        uint256 minNoTokensToReceiveScaled = minNoTokensToReceive;

        uint256 minSwapAmountOut = 0;
        if (minNoTokensToReceiveScaled > outcomeTokenAmount) {
            minSwapAmountOut = minNoTokensToReceiveScaled - outcomeTokenAmount;
        }

        uint256 swappedNoTokens = MarketAMM(amm).swap(yesToken, outcomeTokenAmount, minSwapAmountOut, address(this));

        uint256 totalNoTokens = outcomeTokenAmount + swappedNoTokens;
        if (totalNoTokens < minNoTokensToReceiveScaled) revert(); // InsufficientOutput

        IERC20(noToken).safeTransfer(msg.sender, totalNoTokens);
    }

    function snapshotPnl() external returns (int256) {
        if (block.timestamp >= endTime) revert();
        if (isSettled) revert AlreadySettled();

        (int256 pnl, bool isClosed, bool positionValid) = _calculatePnl();
        
        if (isClosed) {
            // Position is closed - record this and use last valid PnL
            positionWasClosed = true;
            emit PositionClosed(block.timestamp, lastTrackedPnl);
            return lastTrackedPnl;
        }
        
        if (!positionValid) {
            // Position has been changed/gamed - emit warning and return last valid
            (bool success, bytes memory data) = positionReader.staticcall(
                abi.encode(targetUser, uint16(perpId))
            );
            if (success) {
                (int64 newSzi, uint64 newEntryNtl,,,) = abi.decode(data, (int64, uint64, int64, uint32, bool));
                emit PositionChanged(committedSzi, committedEntryNtl, newSzi, newEntryNtl);
            }
            return lastTrackedPnl;
        }

        // Valid position - update tracking
        lastTrackedPnl = pnl;
        lastTrackedTimestamp = block.timestamp;
        return pnl;
    }

    function settle() external nonReentrant {
        if (block.timestamp < endTime) revert();
        if (isSettled) revert AlreadySettled();

        (int256 pnl, bool isClosed, bool positionValid) = _calculatePnl();

        if (isClosed || positionWasClosed) {
            // Position was closed - use last tracked PnL for settlement
            if (lastTrackedTimestamp > 0) {
                outcome = lastTrackedPnl > 0 ? Outcome.Profitable : Outcome.Unprofitable;
            } else {
                outcome = Outcome.Unprofitable;
            }
        } else if (!positionValid) {
            // Position was changed/gamed - use last valid PnL
            if (lastTrackedTimestamp > 0) {
                outcome = lastTrackedPnl > 0 ? Outcome.Profitable : Outcome.Unprofitable;
            } else {
                outcome = Outcome.Unprofitable;
            }
        } else {
            // Position is still valid - use current PnL
            outcome = pnl > 0 ? Outcome.Profitable : Outcome.Unprofitable;
        }

        isSettled = true;
        emit Settled(outcome);
    }

    function claimWinnings(uint256 amount) external nonReentrant {
        if (!isSettled) revert NotSettled();

        if (outcome == Outcome.Profitable) {
            OutcomeToken(yesToken).burn(msg.sender, amount);
        } else if (outcome == Outcome.Unprofitable) {
            OutcomeToken(noToken).burn(msg.sender, amount);
        } else {
            revert NotSettled();
        }

        uint256 usdcAmount = amount / USDC_TO_OUTCOME_TOKEN_SCALAR;
        IERC20(USDC).safeTransfer(msg.sender, usdcAmount);
    }

    function _calculatePnl() internal view returns (int256, bool, bool) {
        // Direct staticcall to position precompile
        (bool success, bytes memory data) = positionReader.staticcall(
            abi.encode(targetUser, uint16(perpId))
        );
        require(success, "Position call failed");
        
        (int64 szi, uint64 entryNtl,,,) = abi.decode(data, (int64, uint64, int64, uint32, bool));

        // Check if position is closed
        if (szi == 0) {
            return (0, true, false);
        }

        // Check if position fingerprint matches committed position
        bool positionMatches = (szi == committedSzi && entryNtl == committedEntryNtl);
        if (!positionMatches) {
            // Position has changed - return last valid PnL if available
            if (lastTrackedTimestamp > 0) {
                return (lastTrackedPnl, false, false);
            }
            return (0, false, false);
        }

        // Direct staticcall to mark price precompile
        (success, data) = markPxReader.staticcall(abi.encode(uint32(perpId)));
        require(success, "Mark price call failed");
        uint64 currentMarkPrice = abi.decode(data, (uint64));

        uint64 entryPrice = entryNtl / uint64(abs(szi));
        int256 pnl = (int256(uint256(currentMarkPrice)) - int256(uint256(entryPrice))) * szi;
        return (pnl, false, true);
    }

    function abs(int256 x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    // TEMPORARY DEBUG FUNCTIONS - Remove in production
    function debugPosition() external view returns (int64 szi, uint64 entryNtl, uint32 leverage, bool isIsolated) {
        (bool success, bytes memory data) = positionReader.staticcall(
            abi.encode(targetUser, uint16(perpId))
        );
        require(success, "Position call failed");
        
        (szi, entryNtl,, leverage, isIsolated) = abi.decode(data, (int64, uint64, int64, uint32, bool));
    }

    function debugMarkPrice() external view returns (uint64) {
        (bool success, bytes memory data) = markPxReader.staticcall(abi.encode(uint32(perpId)));
        require(success, "Mark price call failed");
        return abi.decode(data, (uint64));
    }

    function debugPnl() external view returns (
        int64 szi, 
        uint64 entryNtl, 
        uint64 currentMarkPrice, 
        uint64 entryPrice, 
        int256 pnl, 
        bool isClosed
    ) {
        L1Read reader = L1Read(positionReader);
        L1Read.Position memory pos = reader.position(targetUser, uint16(perpId));

        szi = pos.szi;
        entryNtl = pos.entryNtl;
        
        if (pos.szi == 0) {
            return (szi, entryNtl, 0, 0, 0, true);
        }

        currentMarkPrice = L1Read(markPxReader).markPx(perpId);
        entryPrice = pos.entryNtl / uint64(abs(pos.szi));
        pnl = (int256(uint256(currentMarkPrice)) - int256(uint256(entryPrice))) * pos.szi;
        isClosed = false;
    }
}
