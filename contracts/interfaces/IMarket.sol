// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

interface IMarket {

    function getAmountOut(address fromToken, address toToken,uint amountIn) external view returns (uint amountOut);

    function getAmountIn(address fromToken, address toToken,uint amountOut) external view returns (uint amountIn);

    function swap(address fromToken,uint256 amountIn,address toToken,uint256 amountOut,address user) external;
}
