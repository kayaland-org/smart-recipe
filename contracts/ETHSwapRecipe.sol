// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "./Recipe.sol";

contract ETHSwapRecipe is Recipe {

    constructor(address defaultMarket,address registry,address weth,address payable gasSponsor) public Recipe(defaultMarket,registry,weth,gasSponsor){

    }

    function buyToken(address pool, uint256 buyAmount)external override payable notPaused saveGas(_gasSponsor){
        require(_registry.inRegistry(pool), "Not a Pool");
        uint256 totalAmount=calcToToken(pool,buyAmount);
        require(msg.value >= totalAmount, "Amount ETH too low");
        _WETH.deposit{value: totalAmount}();
        _toBuy(pool,msg.sender,buyAmount);
        if(address(this).balance != 0) {
            msg.sender.transfer(address(this).balance);
        }
        ISmartPool(pool).transfer(msg.sender, ISmartPool(pool).balanceOf(address(this)));
    }

    function _toBuy(address pool,address user,uint256 buyAmount)internal{
        (address[] memory tokens, uint256[] memory amounts) = ISmartPool(pool).calcTokensForAmount(buyAmount);
        for(uint256 i = 0; i < tokens.length; i++) {
            if(_registry.inRegistry(tokens[i])) {
                _toBuy(tokens[i],user, amounts[i]);
            } else {
                (address market,uint256 needWeth)=calcToNeedMinAmountIn(address(_WETH),tokens[i],amounts[i]);
                if(address(_WETH)==tokens[i]){
                    _WETH.transfer(pool,amounts[i]);
                }else{
                    _WETH.transfer(market,needWeth);
                    IMarket(market).swap(address(_WETH),needWeth,tokens[i],amounts[i],pool);
                    //market.delegatecall(abi.encodeWithSignature(swapFun,address(_WETH),needWeth,tokens[i],amounts[i],pool));
                }
            }
        }
        ISmartPool(pool).joinPool(user,buyAmount);
    }

    function sellToken(address pool, uint256 sellAmount,uint256 minEthAmount)external override notPaused saveGas(_gasSponsor){
        require(_registry.inRegistry(pool), "Not a Pool");
        uint256 totalAmount=calcToWeth(pool,sellAmount);
        require(minEthAmount <= totalAmount, "Output ETH amount too low");
        ISmartPool poolProxy= ISmartPool(pool);
        (address[] memory tokens, uint256[] memory amounts) = poolProxy.calcTokensForAmount(sellAmount);
        poolProxy.transferFrom(msg.sender, address(this), sellAmount);
        poolProxy.exitPool(msg.sender,sellAmount);
        for(uint256 i = 0; i < tokens.length; i++) {
            (address market,uint256 getWeth)=calcToMaxAmountOut(tokens[i],address(_WETH),amounts[i]);
            if(address(_WETH)!=tokens[i]){
                IERC20(tokens[i]).transfer(market,amounts[i]);
                IMarket(market).swap(tokens[i],amounts[i],address(_WETH),getWeth,address(this));
                //market.delegatecall(abi.encodeWithSignature(swapFun,tokens[i],amounts[i],address(_WETH),getWeth,address(this)));
            }
        }
        _WETH.withdraw(_WETH.balanceOf(address(this)));
        msg.sender.transfer(address(this).balance);
    }

}
