// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "./Recipe.sol";
pragma experimental ABIEncoderV2;

contract ETHPendingSwapRecipe is Recipe {

    struct Info{
        uint256 buyAmount;
        uint256 payment;
    }

    uint256 public triggerMinCount=100;

    mapping(address=>mapping(address=>Info)) internal buyQueue;
    mapping(address=>mapping(address=>Info)) internal sellQueue;
    mapping(address=>EnumerableSet.AddressSet) internal buyQueueCount;
    mapping(address=>EnumerableSet.AddressSet) internal sellQueueCount;

    constructor(address defaultMarket,address registry,address weth,address payable gasSponsor)
    public
    Recipe(defaultMarket,registry,weth,gasSponsor){

    }

    function setTriggerMinCount(uint256 _triggerMinCount)external onlyOwner{
        require(_triggerMinCount>0);
        triggerMinCount=_triggerMinCount;
    }
    function buyToken(address pool, uint256 buyAmount)external override payable notPaused{
        require(_registry.inRegistry(pool), "Not a Pool");
        uint256 totalAmount=calcToToken(pool,buyAmount);
        require(msg.value >= totalAmount, "Amount ETH too low");
        Info storage info=buyQueue[pool][msg.sender];
        info.buyAmount=info.buyAmount.add(buyAmount);
        info.payment=info.payment.add(msg.value);
        if(!buyQueueCount[pool].contains(msg.sender)){
            buyQueueCount[pool].add(msg.sender);
        }
    }

    function exitPending(address pool,uint256 exitAmount)external{
        require(_registry.inRegistry(pool), "Not a Pool");
        Info storage info=buyQueue[pool][msg.sender];
        require(info.payment>=exitAmount,"ETH pending amount must be >= exitAmount");
        info.payment=info.payment.sub(exitAmount);
        info.buyAmount=canBuyTotalToken(pool,info.payment);
        msg.sender.transfer(exitAmount);
    }

    function calcPoolBuyerCount(address pool)public view returns(uint256){
        return buyQueueCount[pool].length();
    }

    function getMyPendingEth(address pool)public view returns(uint256){
        return buyQueue[pool][msg.sender].payment;
    }

    function calcPoolReceiveEth(address pool)public view returns(uint256){
        uint256 length=buyQueueCount[pool].length();
        uint256 poolEth=0;
        for(uint256 i=0;i<length;i++){
            poolEth=poolEth.add(buyQueue[pool][buyQueueCount[pool].at(i)].payment);
        }
        return poolEth;
    }

    function canBuyTotalToken(address pool,uint256 ethBal)public view returns(uint256){
        uint256 uintPrice=calcToToken(pool,1 ether);
        uint256 totalBuy=ethBal.mul(1e18).div(uintPrice);
        return totalBuy;
    }

    function trigger(address pool)external {
        require(_registry.inRegistry(pool), "Not a Pool");
        require(calcPoolBuyerCount(pool)>=triggerMinCount,"Buyer count must be >= triggerMinCount");
        uint256 ethBal=calcPoolReceiveEth(pool);
        uint256 buyTotalAmount=canBuyTotalToken(pool,ethBal);
        uint256 ethTotalAmount=calcToToken(pool,buyTotalAmount);
        _WETH.deposit{value: ethTotalAmount}();
        _toBuy(pool,address(this),buyTotalAmount);
        uint256 length=buyQueueCount[pool].length();
        uint256 pTokenBal=ISmartPool(pool).balanceOf(address(this));
        for(uint256 i=0;i<length;i++){
            address buyer=buyQueueCount[pool].at(i);
            uint256 payment=buyQueue[pool][buyer].payment;
            if(payment>0){
                uint256 buyAmount= payment.mul(1e18).div(ethBal);
                ISmartPool(pool).transfer(buyer,buyAmount.mul(pTokenBal));
                buyQueue[pool][buyer].buyAmount=0;
                buyQueue[pool][buyer].payment=0;
            }
        }
        for(uint256 i=0;i<length;i++){
            buyQueueCount[pool].remove(buyQueueCount[pool].at(i));
        }
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
                }
            }
        }
        ISmartPool(pool).joinPool(user,buyAmount);
    }

    function sellToken(address pool, uint256 sellAmount,uint256 minEthAmount)external override notPaused{
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
            }
        }
        _WETH.withdraw(_WETH.balanceOf(address(this)));
        msg.sender.transfer(address(this).balance);
    }

}
