// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SpidexFactory} from "../src/SpidexFactory.sol";
import {SpidexPair} from "../src/SpidexPair.sol";
import {Token} from "./mock/MockERC20.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import "../src/libraries/SpidexLibrary.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract SpidexPairTest is Test {
    using Math for uint256;
    using SpidexLibrary for AddressType;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address feeReceiver = makeAddr("feeReceiver");
    Token mkr;
    Token dai;
    SpidexPair mkrDai;

    SpidexFactory factory;

    function setUp() external {
        vm.startPrank(owner);
        mkr = new Token("MKR-Token", "MKR");
        dai = new Token("DAI-Token", "DAI");
        factory = new SpidexFactory();
        mkrDai = SpidexPair(factory.createPair(address(mkr), address(dai)));
        vm.stopPrank();
    }

    function test_intialize() public {
        vm.startPrank(owner);
        vm.expectRevert();
        mkrDai.initialize(address(mkr), address(dai));
        vm.stopPrank();
    }

    function test_pair_factory_address() public view {
        address _factory = mkrDai.factory();
        assertEq(_factory, address(factory));
    }

    function test_initial_reserveBalance() public view {
        uint112 _res0 = mkrDai.reserve0();
        uint112 _res1 = mkrDai.reserve1();
        assertEq(_res0, 0);
        assertEq(_res1, 0);
    }

    function test_mint() public {
        vm.startPrank(user);
        uint256 initialPoolSupply = 100_000 * 1e18;
        mkr.mint(user, initialPoolSupply);
        dai.mint(user, initialPoolSupply);
        mkr.approve(address(mkrDai), initialPoolSupply);
        dai.approve(address(mkrDai), initialPoolSupply);
        mkr.transfer(address(mkrDai), initialPoolSupply);
        dai.transfer(address(mkrDai), initialPoolSupply);
        // checking total supply before mint
        uint256 _ts = mkrDai.totalSupply();
        assertEq(_ts, 0);
        mkrDai.mint(user);

        (uint112 _res0, uint112 _res1,) = mkrDai.getReserves();
        // checking reserves
        console.log("pool supply after mint _res0 :", _res0);
        console.log("pool supply after mint _res1 :", _res1);
        assertEq(_res0, initialPoolSupply);
        assertEq(_res1, initialPoolSupply);
        uint256 expectedLiquidity = Math.sqrt(uint256(_res0) * uint256(_res1));
        uint256 totalSupply = mkrDai.totalSupply();
        assertEq(expectedLiquidity, totalSupply);
        uint256 currentTime = block.timestamp;
        vm.warp(currentTime + 365 days);
        uint256 price0Cummulative = mkrDai.price0CummulativeLast();
        uint256 price1Cummulative = mkrDai.price1CummulativeLast();
        console.log("price 0 cummulative :", price0Cummulative);
        console.log("price 1 cummulative :", price1Cummulative);
        // assertEq(price0Cummulative,1);
        // assertEq(price1Cummulative,1);
        vm.stopPrank();
    }

    function test_mint_after_pool_initialised() public mint {
        uint256 currentTime = block.timestamp;
        vm.warp(currentTime + 365 days);
        vm.startPrank(user);
        uint256 secondSupply = 1000 ether;

        mkr.mint(user, secondSupply);
        dai.mint(user, secondSupply);
        mkr.approve(address(mkrDai), secondSupply);
        dai.approve(address(mkrDai), secondSupply);
        mkr.transfer(address(mkrDai), secondSupply);
        dai.transfer(address(mkrDai), secondSupply);

        mkrDai.mint(user);

        uint256 price0Cummulative = mkrDai.price0CummulativeLast();
        uint256 price1Cummulative = mkrDai.price1CummulativeLast();
        console.log("price 0 cummulative :", price0Cummulative);
        console.log("price 1 cummulative :", price1Cummulative);

        vm.stopPrank();
    }

    function test_burn() public mint {
        vm.startPrank(user);
        uint256 userLpBalance = IERC20(address(mkrDai)).balanceOf(user);
        console.log("user shares :", userLpBalance);
        uint256 totalSupply = mkrDai.totalSupply();
        console.log("total supply :", totalSupply);
        assertEq(totalSupply - userLpBalance, 10 ** 3);

        IERC20(address(mkrDai)).approve(address(mkrDai),1000 ether);
        uint256 balanceBefore = IERC20(address(mkrDai)).balanceOf(address(mkrDai));
        console.log("balance before:",balanceBefore);
        mkrDai.transfer(address(mkrDai), 1000 ether);

        mkrDai.burn(user);
        uint256 balance = IERC20(address(mkrDai)).balanceOf(address(mkrDai));
        console.log("balance after:",balance);
        uint256 liquidityAfter = mkrDai.balanceOf(user);
        assertEq(userLpBalance  - liquidityAfter, 1000 ether);
        vm.stopPrank();
    }


    // function test_swap() external {
    //     vm.startPrank(user2);
    //     dai.mint(user2,1000 ether);
    //     dai.approve(address(mkrDai),1000 ether);
    //     mkrDai.transfer(address(mkrDai), 1000 ether);
    //     if (address(dai) < address (mkr)) {
    //         mkrDai.swap()
    //     }
    //     vm.stopPrank();
    // }

    

    modifier mint() {
        vm.startPrank(user);
        uint256 initialPoolSupply = 100_000 * 1e18;
        mkr.mint(user, initialPoolSupply);
        dai.mint(user, initialPoolSupply);
        mkr.approve(address(mkrDai), initialPoolSupply);
        dai.approve(address(mkrDai), initialPoolSupply);
        mkr.transfer(address(mkrDai), initialPoolSupply);
        dai.transfer(address(mkrDai), initialPoolSupply);
        uint256 _ts = mkrDai.totalSupply();
        mkrDai.mint(user);
        vm.stopPrank();
        _;
    }
}
