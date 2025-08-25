// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OutcomeToken.sol";
import "./MarketAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PriceMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Configuration ---
    address public immutable USDC;
    uint32 public immutable perpId;
    uint256 public immutable endTime;
    uint64 public immutable strikePrice;

    uint256 private constant USDC_DECIMALS = 6;
    uint256 private constant OUTCOME_TOKEN_DECIMALS = 18;
    uint256 private constant USDC_TO_OUTCOME_TOKEN_SCALAR = 10 ** (OUTCOME_TOKEN_DECIMALS - USDC_DECIMALS);

    // --- Deployed Contracts ---
    address public immutable yesToken;
    address public immutable noToken;
    address public immutable amm;

    // --- Settlement ---
    enum Outcome { Undecided, Yes, No } // "Yes" means the condition was met
    Outcome public outcome;
    bool public isSettled;

    // --- Precompile Readers ---
    address public immutable markPxReader;

    event Minted(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);
    event Settled(Outcome outcome);

    error AlreadySettled();
    error NotSettled();
    error NotYetTimeToSettle();

    constructor(
        uint32 _perpId,
        uint256 _endTime,
        uint64 _strikePrice,
        address _usdcTokenAddress,
        address _markPxReader,
        address _yesToken,
        address _noToken,
        address _amm
    ) {
        perpId = _perpId;
        endTime = _endTime;
        strikePrice = _strikePrice;
        USDC = _usdcTokenAddress;
        markPxReader = _markPxReader;
        yesToken = _yesToken;
        noToken = _noToken;
        amm = _amm;
        outcome = Outcome.Undecided;
    }

    // --- Core Functions (mint, redeem, buy) ---
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

    // --- Settlement Logic ---
    function settle() external nonReentrant {
        if (block.timestamp < endTime) revert NotYetTimeToSettle();
        if (isSettled) revert AlreadySettled();

        // Direct staticcall to mark price precompile
        (bool success, bytes memory data) = markPxReader.staticcall(abi.encode(perpId));
        require(success, "Mark price call failed");
        uint64 finalMarkPrice = abi.decode(data, (uint64));

        // The core settlement condition
        if (finalMarkPrice > strikePrice) {
            outcome = Outcome.Yes;
        } else {
            outcome = Outcome.No;
        }

        isSettled = true;
        emit Settled(outcome);
    }

    function claimWinnings(uint256 amount) external nonReentrant {
        if (!isSettled) revert NotSettled();

        if (outcome == Outcome.Yes) {
            // YES token holders win
            OutcomeToken(yesToken).burn(msg.sender, amount);
        } else if (outcome == Outcome.No) {
            // NO token holders win
            OutcomeToken(noToken).burn(msg.sender, amount);
        } else {
            revert NotSettled(); // Should not happen
        }

        uint256 usdcAmount = amount / USDC_TO_OUTCOME_TOKEN_SCALAR;
        IERC20(USDC).safeTransfer(msg.sender, usdcAmount);
    }
}