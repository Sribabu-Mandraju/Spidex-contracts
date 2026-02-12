// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/ISpidexPair.sol";
import "./libraries/SpidexLibrary.sol";

contract SpidexRouter {
    ////////////////////////////////
    //         ERRORS
    ////////////////////////////////
    error SpidexRouter__Expired();
    error SpidexRouter__InsufficientAmount();
    error SpidexRouter__TransferFailed();

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
}
