// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./ERC777.sol";
import "./referrals.sol";

contract ASLICO is Referral{
    constructor(
        uint256 initialSupply,
        address[] memory at
    )
    ERC777("ASLICO", "ASL", at)
   
    {
        _mint(msg.sender, initialSupply, "","");
    }

}