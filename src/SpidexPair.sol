// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpidexERC20} from "./SpidexERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./libraries/UQ112x112.sol";
import {console} from "forge-std/Test.sol";

contract SpidexPair is SpidexERC20 {
    using Math for uint256;
    using UQ112x112 for uint224;

    /////////////////////////////////////////////////
    //               ERRORS
    /////////////////////////////////////////////////
    error Spidex__Unauthourized(address caller);
    error Spidex__TransferFailed(address token, address to);
    error Spidex__InsufficientLiquidity();
    error Spidex__Overflow();
    error Spidex__InsufficientAmount();
    error Spidex__InsufficientBalance();
    error Spidex__InvalidAddress();
    error Spidex__InvalidUniswap_K();

    /////////////////////////////////////////////////
    //              EVENTS
    /////////////////////////////////////////////////
    event Spidex__Mint(address to, uint256 amount);
    event Spidex__Burn(address to, uint256 liquidity);
    event Spidex__Swap(address sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out1);
    event Spidex__ReserveUpdated(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimeStampLast);

    address public factory;
    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;

    uint256 public price0CummulativeLast;
    uint256 public price1CummulativeLast;
    uint32 public blockTimeStampLast;

    uint256 public klast;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        factory = msg.sender;
    }

    /// @dev initialise function to intialise pool tokens
    /// @param tokenA reserve0 address
    /// @param tokenB reserve1 address
    function initialize(address tokenA, address tokenB) external {
        require(msg.sender == factory, Spidex__Unauthourized(msg.sender));
        token0 = tokenA;
        token1 = tokenB;
    }

    /// @dev to handle different types of erc20 transfer functions
    /// @param token address of the token
    /// @param to receiver of the token
    /// @param amount amount to receive
    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), Spidex__TransferFailed(token, to));
    }

    /// @dev to mint shares by adding liquidity to the pool
    /// @param to mint shares for the liquidity providers
    /// @return liquidity the return variables of a contract’s function state variable
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 reserveA, uint112 reserveB,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - reserveA;
        uint256 amount1 = balance1 - reserveB;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0.mulDiv(_totalSupply, reserve0), amount1.mulDiv(_totalSupply, reserve1));
        }
        require(liquidity > 0, Spidex__InsufficientLiquidity());
        _mint(to, liquidity);
        _update(balance0, balance1, reserveA, reserveB);
        emit Spidex__Mint(to, liquidity);
    }

    /// @dev function to remove liquidity by burning LP tokens to get proportioate tokens back
    /// @param to LP address to receive tokens back
    /// @return amount0 and amount1 the return variables of a contract’s function state variable
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;

        uint256 Balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 Balance1 = IERC20(_token1).balanceOf(address(this));

        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply;
        amount0 = liquidity * Balance0 / _totalSupply;
        amount1 = liquidity * Balance1 / _totalSupply;

        require(amount0 > 0 && amount1 > 0, Spidex__InsufficientLiquidity());
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        Balance0 = IERC20(_token0).balanceOf(address(this));
        Balance1 = IERC20(_token1).balanceOf(address(this));

        _update(Balance0, Balance1, _reserve0, _reserve1);
        emit Spidex__Burn(to, liquidity);
    }

    /// @dev swap to tokenA to get equivalent tokenB
    /// @param amount0Out desired amount to get after swap
    /// @param amount1Out desired amount to get after swap
    /// @param to receiver of the amount after swap
    /// @param data to enable arbitary calls
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external lock {
        require(amount0Out > 0 || amount1Out > 0, Spidex__InsufficientAmount());
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out <= _reserve0 && amount1Out <= _reserve1, Spidex__InsufficientBalance());

        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, Spidex__InvalidAddress());
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, Spidex__InsufficientAmount());
        {
            uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
            uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
            require(
                balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * (1000 ** 2),
                Spidex__InvalidUniswap_K()
            );
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Spidex__Swap(to, amount0In, amount1In, amount0Out, amount1Out);
    }

    /// @dev Updates reserves of the pool
    /// @param balance0  actual pool token0 balance
    /// @param balance1 actual pool token1 balance
    /// @param _reserve0 reserve of token0
    /// @param _reserve1 reserve of token1
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, Spidex__Overflow());
        uint32 blockTimeStamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimeStamp - blockTimeStampLast;

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CummulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CummulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            console.log("price0 cumm :", price0CummulativeLast);
            console.log("price1 cumm:", price1CummulativeLast);
            console.log("time elapsed :", timeElapsed);
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimeStampLast = blockTimeStamp;
        emit Spidex__ReserveUpdated(reserve0, reserve1, blockTimeStampLast);
    }

    /////////////////////////////////////
    //      GETTER FUNCTIONS
    ////////////////////////////////////

    function getReserves() public view returns (uint112 reserveA, uint112 reserveB, uint32 lastUpdated) {
        reserveA = reserve0;
        reserveB = reserve1;
        lastUpdated = blockTimeStampLast;
    }
}
