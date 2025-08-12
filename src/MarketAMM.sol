// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MarketAMM is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable tokenA; // YesToken
    address public immutable tokenB; // NoToken
    uint256 public reserveA;
    uint256 public reserveB;

    mapping(address => uint256) public lpShares;
    uint256 public totalLpShares;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event Swapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    error InvalidToken();
    error InsufficientLiquidity();
    error ZeroAmount();
    error InsufficientOutput();

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256) {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        uint256 lpTokensToMint;
        if (totalLpShares == 0) {
            lpTokensToMint = 100 * 1e18; // Initial liquidity
        } else {
            uint256 ratioA = (amountA * totalLpShares) / reserveA;
            uint256 ratioB = (amountB * totalLpShares) / reserveB;
            lpTokensToMint = ratioA < ratioB ? ratioA : ratioB;
        }

        lpShares[msg.sender] += lpTokensToMint;
        totalLpShares += lpTokensToMint;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpTokensToMint);
        return lpTokensToMint;
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address recipient)
        external
        nonReentrant
        returns (uint256)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != tokenA && tokenIn != tokenB) revert InvalidToken();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut;
        address tokenOut;

        if (tokenIn == tokenA) {
            tokenOut = tokenB;
            amountOut = (amountIn * 997 * reserveB) / ((reserveA * 1000) + (amountIn * 997));
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            tokenOut = tokenA;
            amountOut = (amountIn * 997 * reserveA) / ((reserveB * 1000) + (amountIn * 997));
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        if (amountOut < minAmountOut) revert InsufficientOutput();

        IERC20(tokenOut).safeTransfer(recipient, amountOut);

        emit Swapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }
}
