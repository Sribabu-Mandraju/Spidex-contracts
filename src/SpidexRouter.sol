// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/ISpidexPair.sol";
import "./libraries/SpidexLibrary.sol";
import "./interfaces/ISpidexFactory.sol";

contract SpidexRouter {
    ////////////////////////////////
    //         ERRORS
    ////////////////////////////////
    error SpidexRouter__Expired();
    error SpidexRouter__InsufficientAmount();
    error SpidexRouter__TransferFailed();
    error SpidexRouter__InsufficientLiquidity();

    bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant TRANSFER_FROM_SELECTOR = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
    address public immutable factory;
    address public immutable WETH;

    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }

    /// @dev to handle different types of erc20 transfer functions
    /// @param token address of the token
    /// @param to receiver of the token
    /// @param amount amount to receive
    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER_SELECTOR, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), SpidexRouter__TransferFailed());
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), SpidexRouter__TransferFailed());
    }

    modifier ensure(uint256 timeStamp) {
        require(block.timestamp >= timeStamp, SpidexRouter__Expired());
        _;
    }

    function _swap(uint256[] memory amounts, address[] memory path, address to) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address inputToken, address outputToken) = (path[i], path[i + 1]);
            (address token0,) = SpidexLibrary.sortTokens(inputToken, outputToken);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                token0 == inputToken ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address _to = i < path.length - 2 ? SpidexLibrary.computePair(outputToken, path[i + 2], factory) : to;
            ISpidexPair(SpidexLibrary.computePair(inputToken, outputToken, factory)).swap(
                amount0Out, amount1Out, _to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts = SpidexLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[path.length - 1] >= amountOutMin, SpidexRouter__InsufficientAmount());
        _safeTransferFrom(path[0], msg.sender, SpidexLibrary.computePair(path[0], path[1], factory), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = SpidexLibrary.getAmountsIn(factory, amountOut, path);
        require(amountInMax >= amounts[0], SpidexRouter__InsufficientAmount());
        _safeTransferFrom(path[0], msg.sender, SpidexLibrary.computePair(path[0], path[1], factory), amounts[0]);
        _swap(amounts, path, to);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 desiredAmountA,
        uint256 desiredAmountB,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = ISpidexFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = ISpidexFactory(factory).createPair(tokenA, tokenB);
        }

        (uint256 _res0, uint256 _res1) = SpidexLibrary.getReserves(factory, tokenA, tokenB);

        if (_res0 == 0 && _res1 == 0) {
            (amountA, amountB) = (desiredAmountA, desiredAmountB);
        } else {
            uint256 amountBOptimal = SpidexLibrary.quote(desiredAmountA, _res0, _res1);
            if (amountBOptimal <= desiredAmountB) {
                require(amountBOptimal >= amountBMin, SpidexRouter__InsufficientAmount());
                (amountA, amountB) = (desiredAmountA, amountBOptimal);
            } else {
                uint256 amountAOptimal = SpidexLibrary.quote(desiredAmountB, _res1, _res0);
                if (amountAOptimal <= desiredAmountA) {
                    require(amountAOptimal >= amountAMin, SpidexRouter__InsufficientAmount());
                    (amountA, amountB) = (amountAOptimal, desiredAmountB);
                }
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 desiredAmountA,
        uint256 desiredAmountB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, desiredAmountA, desiredAmountB, amountAMin, amountBMin);
        address pair = SpidexLibrary.computePair(tokenA, tokenB, factory);
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ISpidexPair(pair).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = SpidexLibrary.computePair(tokenA, tokenB, factory);
        _safeTransferFrom(pair, msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = ISpidexPair(pair).burn(to);
        (address token0,) = SpidexLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = token0 == tokenA ? (amount0, amount1) : (amount1, amount0);
        require(amountAMin <= amountA, SpidexRouter__InsufficientLiquidity());
        require(amountBMin <= amountB, SpidexRouter__InsufficientLiquidity());
    }
}
