// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

contract PokerTableJoinTableTest is Test {
    PokerTable pokerTable;

    function setUp() public {
        pokerTable = new PokerTable(IERC20(address(0xbeef)), 1 ether);
    }

    function test_playerCanJoin() public {
        pokerTable.joinTable();

        assertTrue(pokerTable.players(address(this)));
    }

    function test_RevertWhen_tableIsFull() public {
        for (uint160 i = 0; i < pokerTable.MAX_PLAYERS(); i++) {
            vm.prank(address(bytes20(i)));
            pokerTable.joinTable();
        }

        vm.expectRevert(IPokerTable.TableIsFull.selector);
        pokerTable.joinTable();
    }
}
