//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "evm-gateway-contract/contracts/IGateway.sol";
import "evm-gateway-contract/contracts/ICrossTalkApplication.sol";
import "evm-gateway-contract/contracts/Utils.sol";

/// @title PingPong
/// @author Yashika Goyal
/// @notice This is a cross-chain ping pong smart contract to demonstrate how one can
/// utilise Router CrossTalk for cross-chain transactions.
contract PingPong is ICrossTalkApplication {
    uint64 public currentRequestId;

    // srcChainType + srcChainId + requestId => pingFromSource
    mapping(uint64 => mapping(string => mapping(uint64 => string)))
        public pingFromSource;
    // requestId => ackMessage
    mapping(uint64 => string) public ackFromDestination;

    // instance of the Router's gateway contract
    IGateway public gatewayContract;

    // gas limit required to handle the cross-chain request on the destination chain.
    uint64 public destGasLimit;

    // gas limit required to handle the acknowledgement received on the source
    // chain back from the destination chain.
    uint64 public ackGasLimit;

    // custom error so that we can emit a custom error message
    error CustomError(string message);

    // event we will emit while sending a ping to destination chain
    event PingFromSource(
        uint64 indexed srcChainType,
        string indexed srcChainId,
        uint64 indexed requestId,
        string message
    );
    event NewPing(uint64 indexed requestId);

    // events we will emit while handling acknowledgement
    event ExecutionStatus(uint64 indexed eventIdentifier, bool isSuccess);
    event AckFromDestination(uint64 indexed requestId, string ackMessage);

    constructor(
        address payable gatewayAddress,
        uint64 _destGasLimit,
        uint64 _ackGasLimit
    ) {
        gatewayContract = IGateway(gatewayAddress);
        destGasLimit = _destGasLimit;
        ackGasLimit = _ackGasLimit;
    }

    function pingDestination(
        // uint64 chainType,
        string memory chainId,
        // uint64 destGasPrice,
        // uint64 ackGasPrice,
        address destinationContractAddress,
        address user0,
        address user1,
        string memory message // uint64 expiryDurationInSeconds
    ) public payable {
        currentRequestId++;
        // creating the payload to be sent to the destination chain
        bytes memory payload = abi.encode(
            currentRequestId,
            user0,
            user1,
            message
        );
        // creating the expiry timestamp
        uint64 expiryTimestamp = uint64(block.timestamp) + 100000000000;

        // creating an array of destination contract addresses in bytes
        bytes[] memory addresses = new bytes[](1);
        addresses[0] = toBytes(destinationContractAddress);

        // creating an array of payloads to be sent to respective destination contracts
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = payload;

        // sending a cross-chain request
        _pingDestination(
            expiryTimestamp,
            80000000000,
            80000000000,
            0,
            chainId,
            payloads,
            addresses
        );

        // emit NewPing(currentRequestId);
    }

    function _pingDestination(
        uint64 expiryTimestamp,
        uint64 destGasPrice,
        uint64 ackGasPrice,
        uint64 chainType,
        string memory chainId,
        bytes[] memory payloads,
        bytes[] memory addresses
    ) internal {
        // Calling the requestToDest function on the Router's Gateway contract to generate a
        // cross-chain request and storing the nonce returned into the lastEventIdentifier.
        gatewayContract.requestToDest(
            expiryTimestamp,
            false,
            Utils.AckType.ACK_ON_SUCCESS,
            Utils.AckGasParams(ackGasLimit, ackGasPrice),
            Utils.DestinationChainParams(
                destGasLimit,
                destGasPrice,
                chainType,
                chainId
            ),
            Utils.ContractCalls(payloads, addresses)
        );
    }

    mapping(address => mapping(address => string[])) public map;
    mapping(address => address[]) public contacts;

    /// @notice function to handle the cross-chain request received from some other chain.
    /// @param srcContractAddress address of the contract on source chain that initiated the request.
    /// @param payload the payload sent by the source chain contract when the request was created.
    /// @param srcChainId chain ID of the source chain in string.
    /// @param srcChainType chain type of the source chain.
    function handleRequestFromSource(
        bytes memory srcContractAddress,
        bytes memory payload,
        string memory srcChainId,
        uint64 srcChainType
    ) external override returns (bytes memory) {
        require(msg.sender == address(gatewayContract));

        (
            uint64 requestId,
            address user0,
            address user1,
            string memory message
        ) = abi.decode(payload, (uint64, address, address, string));

        if (
            keccak256(abi.encodePacked(message)) ==
            keccak256(abi.encodePacked("#NULL#"))
        ) {
            contacts[user0].push(user1);
            contacts[user1].push(user0);
        } else {
            map[user0][user1].push(message);
            map[user1][user0].push(message);
        }

        // pingFromSource[srcChainType][srcChainId][requestId] = sampleStr;

        // emit PingFromSource(srcChainType, srcChainId, requestId, sampleStr);

        return abi.encode(requestId, user0, user1, message);
    }

    function getMessages(
        address u0,
        address u1
    ) public view returns (string[] memory) {
        return map[u0][u1];
    }

    function getContacts(address u0) public view returns (address[] memory) {
        return contacts[u0];
    }

    /// @notice function to handle the acknowledgement received from the destination chain
    /// back on the source chain.
    /// @param eventIdentifier event nonce which is received when we create a cross-chain request
    /// We can use it to keep a mapping of which nonces have been executed and which did not.
    /// @param execFlags an array of boolean values suggesting whether the calls were successfully
    /// executed on the destination chain.
    /// @param execData an array of bytes returning the data returned from the handleRequestFromSource
    /// function of the destination chain.
    function handleCrossTalkAck(
        uint64 eventIdentifier,
        bool[] memory execFlags,
        bytes[] memory execData
    ) external override {
        bytes memory _execData = abi.decode(execData[0], (bytes));

        (uint64 requestId, string memory ackMessage) = abi.decode(
            _execData,
            (uint64, string)
        );

        ackFromDestination[requestId] = ackMessage;

        emit ExecutionStatus(eventIdentifier, execFlags[0]);
        emit AckFromDestination(requestId, ackMessage);
    }

    /// @notice function to convert address to bytes
    function toBytes(address a) public pure returns (bytes memory b) {
        assembly {
            let m := mload(0x40)
            a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(
                add(m, 20),
                xor(0x140000000000000000000000000000000000000000, a)
            )
            mstore(0x40, add(m, 52))
            b := m
        }
    }

    function getMessagesOneByOne(
        address u0,
        address u1,
        uint idx
    ) public view returns (string memory) {
        return map[u0][u1][idx];
    }

    function getContactsOneByOne(
        address u0,
        uint idx
    ) public view returns (address) {
        return contacts[u0][idx];
    }

    function mapLength(address u0, address u1) public view returns (uint) {
        return (map[u0][u1]).length;
    }

    function noOfContacts(address u0) public view returns (uint) {
        return (contacts[u0]).length;
    }
}
