// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

interface IFreeFromUpTo {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function freeFromUpTo(address from, uint256 value) external returns(uint256 freed);
}
