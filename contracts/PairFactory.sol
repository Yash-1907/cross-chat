//SPDX-License-Identifier:MIT
pragma solidity ^0.8.13;

import "./interfaces/IPair.sol";
import "./Pair.sol";
import "hardhat/console.sol";

contract PairFactory {
    mapping(address => mapping(address => address)) getPair;
    address[] public allPairs;

    event PairCreated(
        address indexed userA,
        address indexed userB,
        address pair
    );

    receive() external payable {}

    function createPair(address userA, address userB)
        external
        returns (address pair)
    {
        require(userA != userB, " Cross-Chat : Same addresses");
        (address user0, address user1) = userA < userB
            ? (userA, userB)
            : (userB, userA);
        require(user0 != address(0), "User cannot has zero address");
        require(getPair[user0][user1] == address(0), "Piar already exists");
        console.log("Here");
        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(user0, user1));
        console.log("Here2");
        assembly {
            pair := create2(0xFF, add(bytecode, 32), mload(bytecode), salt)
        }
        console.log("Here3");
        IPair(pair).initialize(user0, user1);
        console.log("Here4");
        // getPair[user0][user1] = pair;
        // getPair[user1][user0] = pair;
        // allPairs.push(pair);

        emit PairCreated(user0, user1, pair);
    }

    function getPairAddress(uint256 id) public view returns (address) {
        return allPairs[id];
    }
}
