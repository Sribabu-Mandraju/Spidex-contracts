// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpidexRouter {
    ////////////////////////////////
    //           ERRORS
    ////////////////////////////////
    error SpidexRouter__Expired();
    error SpidexRouter__InsufficientAmount();
    error SpidexRouter__TransferFailed();

    ////////////////////////////////
    //        VIEW FUNCTIONS
    ////////////////////////////////
    function factory() external view returns (address);
    function WETH() external view returns (address);

    ////////////////////////////////
    //        SWAP FUNCTIONS
    ////////////////////////////////
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
