// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SpidexERC20} from "../src/SpidexERC20.sol";

contract Deploy is Script {
    SpidexERC20 token;

    function run() public {
        vm.startBroadcast();
        token = new SpidexERC20();

        console.log(address(token));
        vm.stopBroadcast();
    }
}
