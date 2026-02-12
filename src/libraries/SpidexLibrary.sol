// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpidexPair} from "../SpidexPair.sol";
import "../interfaces/ISpidexFactory.sol";
import "../interfaces/ISpidexPair.sol";

library SpidexLibrary {
    // sorting tokens based on addresses
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // used to compute address of a pair contract manually;
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

    /// @dev to get expected Y tokens by giving X tokens to the pair, so with this function we can estimate how many  tokens can we get after swap by putting another token
    /// @param amountIn input tokens to the pair to get output tokens
    /// @param _reserveIn reserve of input token in the pool
    /// @param _reserveOut reserve of output token in the pool
    /// @return amountOut expected output amount after swap
    function getAmountOut(uint256 amountIn, uint112 _reserveIn, uint112 _reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Insufficient amount");
        require(_reserveIn > 0 && _reserveOut > 0, "Insufficient liquidity");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * (_reserveOut);
        uint256 denominator = amountInWithFee + (_reserveIn * 1000);
        amountOut = numerator / denominator;
    }

    /// @dev to get desired Y tokens by giving expected X tokens to the pair, so with this function we can estimate how many  tokens do we need to send to pair to get desired amount of tokens
    /// @param amountOut desired output tokens to know how much input tokens needed
    /// @param _reserveIn reserve of input token in the pool
    /// @param _reserveOut reserve of output token in the pool
    /// @return amountIn expected input amount to get resired output amount
    function getAmountIn(uint256 amountOut, uint112 _reserveIn, uint112 _reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "Insufficient amount");
        require(_reserveIn > 0 && _reserveOut > 0, "Insufficient liquidity");
        uint256 numerator = _reserveIn * (amountOut * 1000);
        uint256 denominator = (_reserveOut - amountOut) * 997;
        amountIn = numerator / denominator;
    }

    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        uint256 pathLength = path.length;
        require(pathLength >= 2, "Invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < pathLength - 1; i++) {
            (uint112 _resIn, uint112 _resOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], _resIn, _resOut);
        }
    }

    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        uint256 pathLength = path.length;
        require(pathLength >= 2, "invalid path");
        amounts[pathLength - 1] = amountOut;
        for (uint256 i = pathLength - 1; i > 0; i--) {
            (uint112 _resIn, uint112 _resOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], _resIn, _resOut);
        }
    }

    /// @dev outputs reserves of the pool in the order of inputToken and outputToken
    /// @param factory of the Spidex
    /// @param inputToken of the pair
    /// @param outputToken of the pair
    /// @return _reserveIn of input token
    /// @return _reserveOut of output token
    function getReserves(address factory, address inputToken, address outputToken)
        internal
        view
        returns (uint112 _reserveIn, uint112 _reserveOut)
    {
        address pair = ISpidexFactory(factory).getPair(inputToken, outputToken);
        (address token0,) = sortTokens(inputToken, outputToken);
        (uint112 _reserve0, uint112 _reserve1,) = ISpidexPair(pair).getReserves();
        (_reserveIn, _reserveOut) = inputToken == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
    }

    function quote(uint256 amountA, uint256 _reserveA, uint256 _reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "Insufficient_amount");
        require(_reserveA > 0 && _reserveB > 0, "insufficient reserves");
        amountB = amountA * _reserveB / _reserveA;
    }
}
