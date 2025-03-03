// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";

contract PokerTableConstructorTest is BaseFixtures {
    function test_currencyIsSet() public view {
        IERC20 currency = pokerTable.currency();
        assertFalse(address(currency) == address(0));
    }

    function test_blindPrices() public view {
        // big blind price
        uint256 bigBlindPrice = pokerTable.bigBlindPrice();
        assertEq(bigBlindPrice, 1 ether);

        // small blind price
        uint256 smallBlindPrice = pokerTable.smallBlindPrice();
        assertEq(smallBlindPrice, 0.5 ether);
    }

    function test_smallBlindRoundsDown() public {
        pokerTable = new PokerTable(currency, 3);

        // big blind price
        uint256 bigBlindPrice = pokerTable.bigBlindPrice();
        assertEq(bigBlindPrice, 3);

        // small blind price
        uint256 smallBlindPrice = pokerTable.smallBlindPrice();
        assertEq(smallBlindPrice, 1);
    }

    function test_RevertWhen_bigBlindIsTooLow() public {
        vm.expectRevert(abi.encodeWithSelector(IPokerTable.BigBlindPriceIsTooLow.selector, 1));
        new PokerTable(currency, 1);
    }
}
