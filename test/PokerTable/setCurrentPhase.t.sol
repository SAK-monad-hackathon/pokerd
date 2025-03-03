// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";

contract PokerTableLeaveTableTest is BaseFixtures {
    address player1 = address(1);
    address player2 = address(2);

    function setUp() public override {
        super.setUp();

        uint256 minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.bigBlindPrice();
        vm.prank(player1);
        pokerTable.joinTable(minBuyIn);
        vm.prank(player2);
        pokerTable.joinTable(minBuyIn);

        // sanity check
        assertEq(pokerTable.playerCount(), 2);
    }

    function test_defaultPhase() public view {
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
    }

    function test_setCurrentPhase() public {
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);

        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.PreFlop));
    }

    function test_setCurrentPhaseToPreFlopIsAllowedFromAnyState() public {
        // from `WaitingForPlayers`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);

        // from `PreFlop`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.PreFlop));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);

        // from `Flop`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.PreFlop));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);

        // from `Turn`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.PreFlop));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);

        // from `River`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.PreFlop));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.River);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);
    }

    function test_setCurrentPhaseToWaitingForPlayersIsAllowedFromAnyState() public {
        // from `PreFlop`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `Flop`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `Turn`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `River`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.River);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);
    }

    function test_RevertWhen_setCurrentPhaseSkippingPhase() public {
        vm.expectRevert(IPokerTable.SkippingPhasesIsNotAllowed.selector);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop);
    }

    function test_RevertWhen_notEnoughPlayersToGoToPreFlop() public {
        vm.prank(player2);
        pokerTable.leaveTable();

        vm.expectRevert(IPokerTable.NotEnoughPlayers.selector);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop);
    }
}
