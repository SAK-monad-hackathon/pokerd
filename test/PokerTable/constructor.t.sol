// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {PokerTable} from "../../src/PokerTable.sol";

contract PokerTableConstructorTest is Test {
    function test_currencyIsSet() public {
        PokerTable pokerTable = new PokerTable(IERC20(address(0xbeef)));
        IERC20 currency = pokerTable.currency();
        assertEq(address(currency), address(0xbeef));
    }
}
