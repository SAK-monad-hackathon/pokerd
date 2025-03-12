// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";

contract PokerTableConstructorTest is BaseFixtures {
    function test_currencyIsSet() public view {
        IERC20 CURRENCY = pokerTable.CURRENCY();
        assertFalse(address(CURRENCY) == address(0));
    }

    function test_blindPrices() public view {
        // big blind price
        uint256 BIG_BLIND_PRICE = pokerTable.BIG_BLIND_PRICE();
        assertEq(BIG_BLIND_PRICE, 1 ether);

        // small blind price
        uint256 SMALL_BLIND_PRICE = pokerTable.SMALL_BLIND_PRICE();
        assertEq(SMALL_BLIND_PRICE, 0.5 ether);
    }

    function test_smallBlindRoundsDown() public {
        pokerTable = new PokerTable(CURRENCY, 3);

        // big blind price
        uint256 BIG_BLIND_PRICE = pokerTable.BIG_BLIND_PRICE();
        assertEq(BIG_BLIND_PRICE, 3);

        // small blind price
        uint256 SMALL_BLIND_PRICE = pokerTable.SMALL_BLIND_PRICE();
        assertEq(SMALL_BLIND_PRICE, 1);
    }

    function test_RevertWhen_bigBlindIsTooLow() public {
        vm.expectRevert(abi.encodeWithSelector(IPokerTable.BigBlindPriceIsTooLow.selector, 1));
        new PokerTable(CURRENCY, 1);
    }
}
