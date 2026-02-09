// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpidexPair} from "./SpidexPair.sol";

contract SpidexFactory {
    event SpidexFactory__PairCreated(address pair, address tokenA, address tokenB);

    address feeReceiver;
    address feeReceiveSetter;

    mapping(address token0 => mapping(address token1 => address pair)) public pair;
    address[] public pairs;

    constructor(address _feeReceiver, address _feeReceiverSetter) {
        feeReceiver = _feeReceiver;
        feeReceiveSetter = _feeReceiverSetter;
    }

    function createPair(address _token0, address _token1) external returns (address _pair) {
        require(_token0 != _token1, "invalid tokens");
        (address token0, address token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        require(token0 != address(0), "invalid tokens");
        require(pair[token0][token1] == address(0), "pair already exists");
        bytes memory bytecode = type(SpidexPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            _pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        SpidexPair(_pair).initialize(token0, token1);
        pair[token0][token1] = _pair;
        pair[token1][token0] = _pair;
        pairs.push(_pair);

        emit SpidexFactory__PairCreated(_pair, token0, token1);
    }
}
