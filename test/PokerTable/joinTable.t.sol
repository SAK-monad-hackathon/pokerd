// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";

contract PokerTableJoinTableTest is BaseFixtures {
    uint256 minBuyIn;
    uint256 maxBuyIn;

    function setUp() public override {
        super.setUp();

        minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.bigBlindPrice();
        maxBuyIn = pokerTable.MAX_BUY_IN_BB() * pokerTable.bigBlindPrice();
    }

    function test_playerCanJoin() public {
        pokerTable.joinTable(minBuyIn);

        assertTrue(pokerTable.players(address(this)));
    }

    function test_RevertWhen_tableIsFull() public {
        for (uint160 i = 0; i < pokerTable.MAX_PLAYERS(); i++) {
            vm.prank(address(bytes20(i)));
            pokerTable.joinTable(minBuyIn);
        }

        // sanity check
        assertEq(pokerTable.playerCount(), pokerTable.MAX_PLAYERS());

        vm.expectRevert(IPokerTable.TableIsFull.selector);
        pokerTable.joinTable(minBuyIn);
    }

    function test_RevertWhen_buyInTooLow() public {
        vm.expectRevert(IPokerTable.InvalidBuyIn.selector);
        pokerTable.joinTable(minBuyIn - 1);
    }

    function test_RevertWhen_buyInTooHigh() public {
        vm.expectRevert(IPokerTable.InvalidBuyIn.selector);
        pokerTable.joinTable(maxBuyIn + 1);
    }
}
