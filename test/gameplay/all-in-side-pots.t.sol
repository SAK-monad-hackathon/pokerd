// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

contract AllInSidePotsTest is BaseFixtures {
    uint256 bbAmount;
    uint256 sbAmount;

    function setUp() public override {
        super.setUp();

        bbAmount = pokerTable.BIG_BLIND_PRICE();
        sbAmount = bbAmount / 2;

        // Give players different amounts to test side pots
        MockERC20(address(CURRENCY)).mint(player1, 50 ether); // Small stack
        MockERC20(address(CURRENCY)).mint(player2, 80 ether); // Medium stack
        MockERC20(address(CURRENCY)).mint(player3, 100 ether); // Big stack

        vm.prank(player1);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(player2);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(player3);
        CURRENCY.approve(address(pokerTable), type(uint256).max);

        // Players join with different buy-ins (all valid)
        vm.prank(player1);
        pokerTable.joinTable(50 ether, 0); // Small stack
        vm.prank(player2);
        pokerTable.joinTable(80 ether, 1); // Medium stack
        vm.prank(player3);
        pokerTable.joinTable(100 ether, 2); // Big stack

        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForPlayers);
    }

    function test_allInCreatesCorrectSidePots() public {
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");

        // Expected state after blinds:
        // player1 (SB): 0.5 ether in pot, 49.5 ether balance
        // player2 (BB): 1 ether in pot, 79 ether balance
        // player3: 0 in pot, 100 ether balance

        uint256 player1BalanceBefore = pokerTable.playersBalance(player1);
        uint256 player3BalanceBefore = pokerTable.playersBalance(player3);

        // player3 is first to act, goes all-in with 100 ether
        vm.prank(player3);
        pokerTable.bet(player3BalanceBefore);
        assertTrue(pokerTable.isPlayerAllIn(player3));
        assertEq(pokerTable.playersBalance(player3), 0);

        // player1 goes all-in with remaining balance
        vm.prank(player1);
        pokerTable.bet(player1BalanceBefore);
        assertTrue(pokerTable.isPlayerAllIn(player1));
        assertEq(pokerTable.playersBalance(player1), 0);

        // Check current phase - it might have advanced due to all-in logic
        IPokerTable.GamePhases currentPhase = pokerTable.currentPhase();

        // If still in betting phase, let player2 bet
        if (currentPhase == IPokerTable.GamePhases.PreFlop) {
            uint256 currentBettor = pokerTable.currentBettorIndex();

            assertEq(currentBettor, 1, "Expected player2 to be next bettor");

            uint256 player2Balance = pokerTable.playersBalance(player2);
            vm.prank(player2);
            pokerTable.bet(player2Balance);
        }

        goToPhase(IPokerTable.GamePhases.WaitingForResult);

        string[] memory cards = new string[](5);
        cards[0] = "As Ks"; // player1 - winner
        cards[1] = "Qh Jh"; // player2
        cards[2] = "2c 3c"; // player3
        cards[3] = ""; // empty
        cards[4] = ""; // empty

        uint256[] memory winners = new uint256[](1);
        winners[0] = 0; // player1 wins

        pokerTable.revealShowdownResult(cards, winners);

        // player1 wins with the smallest stack, so he can only win the main pot
        // Main pot calculation:
        // - player1 contributed 50 ether (0.5 SB + 49.5 all-in)
        // - player2 contributed 50 ether (matching player1's total)
        // - player3 contributed 50 ether (matching player1's total)
        // Main pot = 50 * 3 players = 150 ether
        uint256 expectedPlayer1Balance = 150 ether;
        assertEq(pokerTable.playersBalance(player1), expectedPlayer1Balance);

        // Check that side pots were created correctly
        IPokerTable.RoundData memory roundData = pokerTable.getRoundData(pokerTable.currentRoundId() - 1);
        assertGt(roundData.sidePots.length, 0, "Side pots should be created");
    }

    function test_multipleAllInsWithDifferentWinners() public {
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");

        // All players go all-in
        uint256 player3BalanceBefore = pokerTable.playersBalance(player3);
        vm.prank(player3);
        pokerTable.bet(player3BalanceBefore);
        uint256 player1BalanceBefore = pokerTable.playersBalance(player1);
        vm.prank(player1);
        pokerTable.bet(player1BalanceBefore);

        // player2 goes all-in with his remaining balance (after BB deduction)
        uint256 player2CurrentBalance = pokerTable.playersBalance(player2);
        vm.prank(player2);
        pokerTable.bet(player2CurrentBalance);

        goToPhase(IPokerTable.GamePhases.WaitingForResult);

        string[] memory cards = new string[](5);
        cards[0] = "2c 3c"; // player1
        cards[1] = "As Ks"; // player2 - winner
        cards[2] = "Qh Jh"; // player3
        cards[3] = ""; // empty
        cards[4] = ""; // empty

        uint256[] memory winners = new uint256[](1);
        winners[0] = 1; // player2 wins

        uint256 player2BalanceBeforeShowdown = pokerTable.playersBalance(player2);

        pokerTable.revealShowdownResult(cards, winners);

        // player2 should win more than just the main pot since he has a bigger stack than player1
        assertGt(pokerTable.playersBalance(player2), player2BalanceBeforeShowdown + 30 ether);
    }

    function test_allInPlayerCannotBetFurther() public {
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");

        // player3 goes all-in first
        uint256 player3BalanceBefore = pokerTable.playersBalance(player3);
        vm.prank(player3);
        pokerTable.bet(player3BalanceBefore);

        // player1 goes all-in
        uint256 player1BalanceBefore = pokerTable.playersBalance(player1);
        vm.prank(player1);
        pokerTable.bet(player1BalanceBefore);
        assertTrue(pokerTable.isPlayerAllIn(player1));

        // player2 should now be the current bettor
        // Verify that player2 cannot make a small bet (must call the full amount or go all-in)
        vm.prank(player2);
        vm.expectRevert(IPokerTable.BetTooSmall.selector);
        pokerTable.bet(10 ether); // This should fail as it's too small

        // But player2 should be able to go all-in
        uint256 player2Balance = pokerTable.playersBalance(player2);
        vm.prank(player2);
        pokerTable.bet(player2Balance); // This should succeed

        assertTrue(pokerTable.isPlayerAllIn(player2), "player2 should be all-in");
    }
}
