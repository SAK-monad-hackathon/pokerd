// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

contract PokerTableLeaveTableTest is Test {
    PokerTable pokerTable;

    function setUp() public {
        pokerTable = new PokerTable(IERC20(address(0xbeef)), 1 ether);
        pokerTable.joinTable();

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
