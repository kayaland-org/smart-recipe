// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface ISmartPool is IERC20{

    function calcTokensForAmount(uint256 buyAmount) external view returns (address[] memory tokens, uint256[] memory amounts);

    function joinPool(address user,uint256 buyAmount)external;

    function exitPool(address user,uint256 sellAmount)external;

    function getJoinFeeRatio() external view returns (uint256);

    function getExitFeeRatio() external view returns (uint256);

}
