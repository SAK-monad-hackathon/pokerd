// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";

contract PokerTableLeaveTableTest is BaseFixtures {
    uint256 minBuyIn;

    function setUp() public override {
        super.setUp();

        minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.BIG_BLIND_PRICE();
        pokerTable.joinTable(minBuyIn, 0);

        // sanity check
        assertTrue(pokerTable.players(address(this)));
    }

    function test_playerCanLeave() public {
        uint256 playerBalanceBefore = CURRENCY.balanceOf(address(this));

        pokerTable.leaveTable();

        assertEq(CURRENCY.balanceOf(address(pokerTable)), 0);
        assertEq(CURRENCY.balanceOf(address(this)), playerBalanceBefore + minBuyIn);
        assertEq(pokerTable.playersBalance(address(this)), 0);

        assertFalse(pokerTable.players(address(this)));
        assertEq(pokerTable.playerCount(), 0);
    }

    function test_RevertWhen_playerDidNotJoinTable() public {
        vm.prank(address(0x1));
        vm.expectRevert(IPokerTable.NotAPlayer.selector);
        pokerTable.leaveTable();
    }
}
