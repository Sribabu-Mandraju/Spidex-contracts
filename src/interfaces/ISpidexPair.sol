// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpidexPair {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Spidex__Mint(address indexed to, uint256 amount);
    event Spidex__Burn(address indexed to, uint256 liquidity);
    event Spidex__Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out
    );
    event Spidex__ReserveUpdated(
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimeStampLast
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    /*//////////////////////////////////////////////////////////////
                              STATE
    //////////////////////////////////////////////////////////////*/

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function blockTimeStampLast() external view returns (uint32);

    function price0CummulativeLast() external view returns (uint256);
    function price1CummulativeLast() external view returns (uint256);

    function klast() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                              CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    function initialize(address tokenA, address tokenB) external;

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    function getReserves()
        external
        view
        returns (
            uint112 reserveA,
            uint112 reserveB,
            uint32 lastUpdated
        );
}
