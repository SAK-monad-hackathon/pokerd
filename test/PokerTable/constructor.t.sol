// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

contract PokerTableConstructorTest is Test {
    PokerTable pokerTable;

    function setUp() public {
        pokerTable = new PokerTable(IERC20(address(0xbeef)), 2);
    }

    function test_currencyIsSet() public view {
        // currency
        IERC20 currency = pokerTable.currency();
        assertEq(address(currency), address(0xbeef));
    }

    function test_blindPrices() public view {
        // big blind price
        uint256 bigBlindPrice = pokerTable.bigBlindPrice();
        assertEq(bigBlindPrice, 2);

        // small blind price
        uint256 smallBlindPrice = pokerTable.smallBlindPrice();
        assertEq(smallBlindPrice, 1);
    }

    function test_smallBlindRoundsDown() public {
        pokerTable = new PokerTable(IERC20(address(0xbeef)), 3);

        // big blind price
        uint256 bigBlindPrice = pokerTable.bigBlindPrice();
        assertEq(bigBlindPrice, 3);

        // small blind price
        uint256 smallBlindPrice = pokerTable.smallBlindPrice();
        assertEq(smallBlindPrice, 1);
    }

    function test_RevertWhen_bigBlindIsTooLow() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IPokerTable.BigBlindPriceIsTooLow.selector,
                1
            )
        );
        new PokerTable(IERC20(address(0xbeef)), 1);
    }
}
