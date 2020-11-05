// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/smart-pool/ISmartPool.sol";
import "./interfaces/smart-pool/ISmartPoolRegister.sol";
import "./interfaces/weth/IWETH.sol";
import "./interfaces/IMarket.sol";
import "./interfaces/gasSaver/ChiGasSaver.sol";

abstract contract Recipe is ChiGasSaver,Ownable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    bool private isPaused = false;

    IWETH public _WETH;

    EnumerableSet.AddressSet private _markets;

    ISmartPoolRegistry public _registry;

    address payable public _gasSponsor;

    string internal constant swapFun = "swap(address,uint256,address,uint256,address)";

    constructor(address defaultMarket,address registry,address weth,address payable gasSponsor) public{
        require(defaultMarket.isContract(),"The address is not contract!");
        require(registry.isContract(),"The address is not contract!");
        require(weth.isContract(),"The address is not contract!");
        _markets.add(defaultMarket);
        _registry=ISmartPoolRegistry(registry);
        _WETH=IWETH(weth);
        _gasSponsor=gasSponsor;
    }

    modifier notPaused {
        require(!isPaused,"SmartRecipe is Paused");
        _;
    }

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
    }

    function destroy() external onlyOwner {
        address payable _to = payable(owner());
        selfdestruct(_to);
    }

    function cleanEth() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function cleanToken(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function addMarket(address market)external onlyOwner{
        require(!_markets.contains(market),"The market already exists!");
        _markets.add(market);
    }

    function removeMarket(address market)external onlyOwner{
        require(_markets.contains(market),"The market not exists!");
        _markets.remove(market);
    }

    fallback() external payable {

    }
    receive() external payable {

    }

    function calcToToken(address pool,uint256 buyAmount) public view returns (uint256){
        (address[] memory tokens, uint256[] memory amounts) = ISmartPool(pool).calcTokensForAmount(buyAmount);
        uint256 totalEth = 0;
        for(uint256 i = 0; i < tokens.length; i++) {
            if(_registry.inRegistry(tokens[i])) {
                totalEth=totalEth.add(calcToToken(tokens[i], amounts[i]));
            } else {
                (,uint256 needEth)=calcToNeedMinAmountIn(address(_WETH),tokens[i],amounts[i]);
                totalEth=totalEth.add(needEth);
            }
        }
        return totalEth;
    }

    function calcToNeedMinAmountIn(address fromToken, address toToken,uint amountOut)public view returns(address market,uint minAmount){
        if(fromToken==toToken){
            return (address(0),amountOut);
        }
        minAmount=0;
        for(uint256 i = 0; i < _markets.length(); i++) {
            market=_markets.at(i);
            uint256 needWeth=IMarket(market).getAmountIn(fromToken,toToken,amountOut);
            if(minAmount==0||needWeth<minAmount){
                minAmount=needWeth;
            }
        }
        return (market,minAmount);
    }


    function calcToWeth(address pool,uint256 sellAmount) public view returns (uint256){
        (address[] memory tokens, uint256[] memory amounts) = ISmartPool(pool).calcTokensForAmount(sellAmount);
        uint256 totalEth = 0;
        for(uint256 i = 0; i < tokens.length; i++) {
            if(_registry.inRegistry(tokens[i])) {
                totalEth=totalEth.add(calcToWeth(tokens[i], amounts[i]));
            } else {
                (,uint256 getEth)=calcToMaxAmountOut(tokens[i],address(_WETH),amounts[i]);
                totalEth=totalEth.add(getEth);
            }
        }
        return totalEth;
    }

    function calcToMaxAmountOut(address fromToken, address toToken,uint amountOut)public view returns(address market,uint maxAmount){
        if(fromToken==toToken){
            return (address(0),amountOut);
        }
        maxAmount=0;
        for(uint256 i = 0; i < _markets.length(); i++) {
            market=_markets.at(i);
            uint256 getWeth=IMarket(market).getAmountOut(fromToken,toToken,amountOut);
            if(maxAmount==0||getWeth>maxAmount){
                maxAmount=getWeth;
            }
        }
        return (market,maxAmount);
    }

    function buyToken(address pool, uint256 buyAmount)external virtual payable notPaused saveGas(_gasSponsor){

    }

    function sellToken(address pool, uint256 sellAmount,uint256 minEthAmount)external virtual notPaused saveGas(_gasSponsor){

    }
}
