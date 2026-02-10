// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpidexFactory {
    event SpidexFactory__PairCreated(
        address indexed pair,
        address indexed tokenA,
        address indexed tokenB
    );

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function pair(
        address token0,
        address token1
    ) external view returns (address pair);

    function pairs(uint256 index) external view returns (address pair);
}
