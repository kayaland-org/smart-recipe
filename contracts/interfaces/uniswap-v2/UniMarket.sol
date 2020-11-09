// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../IMarket.sol";

contract  UniMarket is IMarket{

    using SafeMath for uint;

    address  public _factory;

    constructor(address factory)public{
        _factory=factory;
    }
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniMarket: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniMarket: ZERO_ADDRESS');
    }
    function pairFor(address factory, address tokenA, address tokenB) public pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }
    function getReserves(address tokenA, address tokenB) public view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        IUniswapV2Pair pair = IUniswapV2Pair(pairFor(address(_factory),tokenA, tokenB));
        (uint reserve0, uint reserve1,) = pair.getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function token0Or1(address tokenA, address tokenB) public pure returns(uint256) {
        (address token0,) = sortTokens(tokenA, tokenB);
        if(token0 == tokenB) {
            return 0;
        }
        return 1;
    }

    function getAmountOut(address fromToken, address toToken,uint amountIn) external override view returns (uint amountOut) {
        require(amountIn > 0, 'UniMarket: INSUFFICIENT_INPUT_AMOUNT');
        (uint256 reserveIn, uint256 reserveOut) = getReserves(fromToken, toToken);
        require(reserveIn > 0 && reserveOut > 0, 'UniMarket: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function getAmountIn(address fromToken, address toToken,uint amountOut) external override view returns (uint amountIn) {
        require(amountOut > 0, 'UniMarket: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint256 reserveIn, uint256 reserveOut) = getReserves(fromToken, toToken);
        require(reserveIn > 0 && reserveOut > 0, 'UniMarket: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    function swap(address fromToken,uint256 amountIn,address toToken,uint256 amountOut,address user) external override{
        IUniswapV2Pair pair = IUniswapV2Pair(pairFor(address(_factory),fromToken, toToken));
        IERC20(fromToken).transfer(address(pair), amountIn);
        if(token0Or1(fromToken, toToken) == 0) {
            pair.swap(amountOut,0, user, new bytes(0));
        } else {
            pair.swap(0,amountOut, user, new bytes(0));
        }
    }
}
