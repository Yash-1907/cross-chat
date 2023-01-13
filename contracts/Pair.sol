//SPDX-License-Identifier:MIT
pragma solidity ^0.8.13;

import "./interfaces/IPair.sol";

contract Pair is IPair {
    address public factory;
    address public user0;
    address public user1;

    function initialize(address _user0, address _user1) external {
        require(msg.sender == factory, "Invalid");
        user0 = _user0;
        user1 = _user1;
    }

    receive() external payable {}
}
