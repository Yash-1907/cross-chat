//SPDX-License-Identifier:MIT
pragma solidity ^0.8.13;

// import "./interfaces/IPair.sol";
// import "./Pair.sol";
import "hardhat/console.sol";



interface IPair {
    function initialize(address, address) external;
}

contract Pair is IPair {
    address public factory;
    address public user0;
    address public user1;

    function initialize(address _user0, address _user1) external {
        // require(msg.sender == factory, "Invalid");
        console.log("In Init");
        user0 = _user0;
        user1 = _user1;
    }

    receive() external payable {}
}


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
        Pair spawn = new Pair();
        // spawn = new Pair(pair);
        IPair(spawn).initialize(user0, user1);
        console.log("Here4");
        getPair[user0][user1] = address(spawn);
        getPair[user1][user0] = address(spawn);
        allPairs.push(address(spawn));
        console.log(address(spawn));

        emit PairCreated(user0, user1, pair);
    }

    function getPairAddress(uint256 id) public view returns (address) {
        return allPairs[id];
    }
}
