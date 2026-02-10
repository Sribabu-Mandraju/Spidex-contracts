// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpidexPair} from "../SpidexPair.sol";

library SpidexLibrary {
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function computePair(address tokenA, address tokenB, address factory) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(SpidexPair).creationCode)
                        )
                    )
                )
            )
        );
    }
}
