// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {PokerTable} from "../src/PokerTable.sol";

contract CounterScript is Script {
    address constant WRAPPED_MONAD = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;

    PokerTable public pokerTable;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        pokerTable = new PokerTable(IERC20(WRAPPED_MONAD));

        vm.stopBroadcast();
    }
}
