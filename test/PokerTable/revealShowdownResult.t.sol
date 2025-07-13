// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin-contracts-5/access/Ownable.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

contract PokerTableRevealShowdownResultTest is BaseFixtures {
    function setUp() public override {
        super.setUp();

        uint256 minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.BIG_BLIND_PRICE();

        vm.startPrank(player1);
        CURRENCY.approve(address(pokerTable), minBuyIn);
        MockERC20(address(CURRENCY)).mint(player1, minBuyIn);
        pokerTable.joinTable(minBuyIn, 0);
        vm.stopPrank();

        vm.startPrank(player2);
        CURRENCY.approve(address(pokerTable), minBuyIn);
        MockERC20(address(CURRENCY)).mint(player2, minBuyIn);
        pokerTable.joinTable(minBuyIn, 1);
        vm.stopPrank();

        vm.startPrank(player3);
        CURRENCY.approve(address(pokerTable), minBuyIn);
        MockERC20(address(CURRENCY)).mint(player3, minBuyIn);
        pokerTable.joinTable(minBuyIn, 2);
        vm.stopPrank();

        pokerTable.setFeeCollector(feeCollector);

        assertEq(pokerTable.playerCount(), 3);
    }

    function test_noFeesWhenPotEvenlyDivisible() public {
        // Create a scenario where pot is evenly divisible

        goToPhase(IPokerTable.GamePhases.WaitingForDealer);
        goToPhase(IPokerTable.GamePhases.WaitingForResult);

        uint256 initialFeeCollectorBalance = CURRENCY.balanceOf(feeCollector);

        string[] memory cards = new string[](5);
        cards[0] = "AsKs"; // player1 wins
        cards[1] = "QhQd"; // player2 wins
        cards[2] = "2c3h"; // player3 loses
        cards[3] = "";
        cards[4] = "";

        uint256[] memory winners = new uint256[](2);
        winners[0] = 0; // player1
        winners[1] = 1; // player2

        // Check current pot before showdown
        uint256 currentPotValue = pokerTable.currentPot();
        uint256 expectedFees = currentPotValue % 2;
        assertEq(expectedFees, 0, "Expected fees should be 0");

        pokerTable.revealShowdownResult(cards, winners);

        uint256 finalFeeCollectorBalance = CURRENCY.balanceOf(feeCollector);

        assertEq(finalFeeCollectorBalance - initialFeeCollectorBalance, expectedFees);
    }

    function test_feeCollectionWithGuaranteedOddPot() public {
        // Create a specific scenario to generate fees by having a side pot amount that
        // doesn't divide evenly among the eligible winners. We'll use unusual bet amounts.

        PokerTable smallPokerTable = new PokerTable(CURRENCY, 7); // BIG_BLIND = 7, SMALL_BLIND = 3
        smallPokerTable.setFeeCollector(feeCollector);

        uint256 minBuyIn = smallPokerTable.MIN_BUY_IN_BB() * smallPokerTable.BIG_BLIND_PRICE();

        // Setup 3 players
        vm.startPrank(player1);
        CURRENCY.approve(address(smallPokerTable), minBuyIn);
        MockERC20(address(CURRENCY)).mint(player1, minBuyIn);
        smallPokerTable.joinTable(minBuyIn, 0);
        vm.stopPrank();

        vm.startPrank(player2);
        CURRENCY.approve(address(smallPokerTable), minBuyIn);
        MockERC20(address(CURRENCY)).mint(player2, minBuyIn);
        smallPokerTable.joinTable(minBuyIn, 1);
        vm.stopPrank();

        vm.startPrank(player3);
        CURRENCY.approve(address(smallPokerTable), minBuyIn);
        MockERC20(address(CURRENCY)).mint(player3, minBuyIn);
        smallPokerTable.joinTable(minBuyIn, 2);
        vm.stopPrank();

        // Start the game - creates: player1: 3 (SB), player2: 7 (BB), player3: 0
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");

        // Player3 calls BB (bets 7 to match): player1: 3, player2: 7, player3: 7
        vm.prank(player3);
        smallPokerTable.bet(7);

        // Player1 calls BB (bets 4 more to reach 7): player1: 7, player2: 7, player3: 7
        vm.prank(player1);
        smallPokerTable.bet(4);

        // Player2 checks (already at 7)

        // Skip to showdown
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForFlop, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForTurn, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForRiver, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.River, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForResult, "");

        uint256 initialFeeCollectorBalance = CURRENCY.balanceOf(feeCollector);

        // Total pot is 21 wei (7 + 7 + 7)
        uint256 currentPotValue = smallPokerTable.currentPot();
        assertEq(currentPotValue, 21);

        // All players contributed 7 wei each, so there's only one side pot level:
        // - Level 7: 7 wei * 3 players = 21 wei, eligible to all 3

        string[] memory cards = new string[](5);
        cards[0] = "AsKs"; // player1 wins
        cards[1] = "QhQd"; // player2 wins
        cards[2] = "2c3h"; // player3 loses (to create uneven division)
        cards[3] = "";
        cards[4] = "";

        // Only 2 winners for the 21 wei pot: 21 ÷ 2 = 10 each + 1 remainder = 1 fee
        uint256[] memory winners = new uint256[](2);
        winners[0] = 0; // player1
        winners[1] = 1; // player2

        smallPokerTable.revealShowdownResult(cards, winners);

        uint256 finalFeeCollectorBalance = CURRENCY.balanceOf(feeCollector);
        uint256 feesCollected = finalFeeCollectorBalance - initialFeeCollectorBalance;

        // Expected: 21 wei ÷ 2 eligible winners = 10 each + 1 remainder
        assertEq(feesCollected, 1, "Should collect 1 wei fee from 21 divided by 2 = 1 remainder");
        // Verify fees are collected when division creates remainder
        assertTrue(feesCollected > 0, "Fees should be collected when pot doesn't divide evenly among winners");
    }

    function test_setFeeCollector() public {
        address newFeeCollector = address(123);

        pokerTable.setFeeCollector(newFeeCollector);
        assertEq(pokerTable.feeCollector(), newFeeCollector);

        pokerTable.setFeeCollector(address(0));
        assertEq(pokerTable.feeCollector(), address(0));
    }

    function test_RevertWhen_setFeeCollectorCallerIsNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1)));
        vm.prank(address(1));
        pokerTable.setFeeCollector(address(123));
    }

    function test_RevertWhen_revealShowdownResultNotWaitingForResult() public {
        // Try to call revealShowdownResult when not in WaitingForResult phase
        vm.expectRevert(
            abi.encodeWithSelector(
                IPokerTable.InvalidState.selector,
                IPokerTable.GamePhases.WaitingForPlayers,
                IPokerTable.GamePhases.WaitingForResult
            )
        );

        string[] memory cards = new string[](5);
        uint256[] memory winners = new uint256[](1);
        winners[0] = 0;

        pokerTable.revealShowdownResult(cards, winners);
    }

    function test_RevertWhen_revealShowdownResultInvalidCardsLength() public {
        // Go to correct phase first
        goToPhase(IPokerTable.GamePhases.WaitingForResult);

        string[] memory cards = new string[](3); // Wrong length, should be 5
        uint256[] memory winners = new uint256[](1);
        winners[0] = 0;

        vm.expectRevert(IPokerTable.InvalidShowdownResults.selector);
        pokerTable.revealShowdownResult(cards, winners);
    }

    function test_RevertWhen_revealShowdownResultInvalidWinnersLength() public {
        // Go to correct phase first
        goToPhase(IPokerTable.GamePhases.WaitingForResult);

        string[] memory cards = new string[](5);
        uint256[] memory winners = new uint256[](0); // No winners

        vm.expectRevert(IPokerTable.InvalidShowdownResults.selector);
        pokerTable.revealShowdownResult(cards, winners);
    }

    function test_RevertWhen_revealShowdownResultCallerIsNotOwner() public {
        // Go to correct phase first
        goToPhase(IPokerTable.GamePhases.WaitingForResult);

        string[] memory cards = new string[](5);
        uint256[] memory winners = new uint256[](1);
        winners[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1)));
        vm.prank(address(1));
        pokerTable.revealShowdownResult(cards, winners);
    }
}
