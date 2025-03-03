// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";

contract PokerTableLeaveTableTest is BaseFixtures {
    function setUp() public override {
        super.setUp();

        pokerTable.joinTable(pokerTable.MIN_BUY_IN_BB() * pokerTable.bigBlindPrice());

        // sanity check
        assertTrue(pokerTable.players(address(this)));
    }

    function test_playerCanLeave() public {
        pokerTable.leaveTable();

        assertFalse(pokerTable.players(address(this)));
    }

    function test_RevertWhen_playerDidNotJoinTable() public {
        vm.prank(address(0x1));
        vm.expectRevert(IPokerTable.NotAPlayer.selector);
        pokerTable.leaveTable();
    }
}
