// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {MockERC20} from "./MockERC20.sol";

contract BaseFixtures is Test {
    PokerTable pokerTable;
    IERC20 currency;

    function setUp() public virtual {
        currency = new MockERC20();
        pokerTable = new PokerTable(currency, 1 ether);

        currency.approve(address(pokerTable), type(uint256).max);
        MockERC20(address(currency)).mint(address(this), 100 ether);
    }

    function goToPhase(IPokerTable.GamePhases _toPhase) internal {
        uint256 _fromPhase = uint256(pokerTable.currentPhase());
        if (uint256(_toPhase) == _fromPhase) {
            return;
        }

        if (_toPhase == IPokerTable.GamePhases.WaitingForPlayers || _toPhase == IPokerTable.GamePhases.WaitingForDealer)
        {
            pokerTable.setCurrentPhase(_toPhase, "");
            return;
        }

        for (uint256 i = _fromPhase + 1; i < uint256(_toPhase); i++) {
            pokerTable.setCurrentPhase(IPokerTable.GamePhases(i), "");
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Utilities                                 */
    /* -------------------------------------------------------------------------- */

    function assertEq(IPokerTable.GamePhases a, IPokerTable.GamePhases b) internal pure {
        assertEq(a, b, "");
    }

    function assertEq(IPokerTable.GamePhases a, IPokerTable.GamePhases b, string memory err) internal pure {
        assertEq(uint256(a), uint256(b), err);
    }
}
