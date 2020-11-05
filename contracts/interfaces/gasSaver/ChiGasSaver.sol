// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;
import "./IFreeFromUpTo.sol";

contract ChiGasSaver {

    modifier saveGas(address payable sponsor) {
        uint256 gasStart = gasleft();
        _;
        uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;

        IFreeFromUpTo chi = IFreeFromUpTo(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);
        if(chi.balanceOf(sponsor)>0&&chi.allowance(sponsor,address(this))>0){
            chi.freeFromUpTo(sponsor, (gasSpent + 14154) / 41947);
        }
    }
}