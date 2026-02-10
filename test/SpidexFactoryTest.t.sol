// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SpidexFactory} from "../src/SpidexFactory.sol";
import {SpidexPair} from "../src/SpidexPair.sol";
import {Token} from "./mock/MockERC20.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import "../src/libraries/SpidexLibrary.sol";

contract SpidexFactoryTest is Test {
    using SpidexLibrary for AddressType;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address feeReceiver = makeAddr("feeReceiver");
    Token usdc;
    Token dai;
    address usdcDai;

    SpidexFactory factory;

    function setUp() external {
        vm.startPrank(owner);
        usdc = new Token("USDC-Token", "USDC");
        dai = new Token("DAI-Token", "DAI");
        factory = new SpidexFactory();
        usdcDai = factory.createPair(address(usdc), address(dai));
        vm.stopPrank();
    }

    function test_pair_contract_token_meta_data() public view {
        address _token0 = SpidexPair(usdcDai).token0();
        address _token1 = SpidexPair(usdcDai).token1();
        (address tokenA, address tokenB) = SpidexLibrary.sortTokens(address(usdc), address(dai));
        assertEq(_token0, tokenA);
        assertEq(_token1, tokenB);
    }

    function test_deployed_pair_contract_address() public view {
        address deployedPairContractAddress = SpidexLibrary.computePair(address(usdc), address(dai), address(factory));
        assertEq(deployedPairContractAddress,address(usdcDai));
    }

    function test_deploying_already_existed_pair_contract() public {
        vm.expectRevert();
        factory.createPair(address(usdc), address(dai));
    }
}
