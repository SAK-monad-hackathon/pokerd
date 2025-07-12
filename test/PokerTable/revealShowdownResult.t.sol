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
        // Create a scenario with guaranteed fees by making pot = 7 wei with 3 winners
        // 7 wei / 3 = 2 wei each, 1 wei fees

        // Deploy a new table with smaller blinds to test with smaller amounts
        PokerTable smallPokerTable = new PokerTable(CURRENCY, 7); // BIG_BLIND = 7, SMALL_BLIND = 3
        smallPokerTable.setFeeCollector(feeCollector);

        // Add 3 players to the small table
        uint256 minBuyIn = smallPokerTable.MIN_BUY_IN_BB() * smallPokerTable.BIG_BLIND_PRICE();

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

        // Go to WaitingForDealer (pot will be 7 + 3 = 10)
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");

        // Go through all phases to reach WaitingForResult
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForFlop, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForTurn, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForRiver, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.River, "");
        smallPokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForResult, "");

        uint256 initialFeeCollectorBalance = CURRENCY.balanceOf(feeCollector);

        // Pot = 10, with 3 winners: 10/3 = 3 each, 1 fee
        uint256 currentPotValue = smallPokerTable.currentPot();
        assertEq(currentPotValue, 10); // 7 (BB) + 3 (SB) = 10

        uint256 expectedFees = currentPotValue % 3; // 10 % 3 = 1
        assertEq(expectedFees, 1); // Should have 1 wei fees

        string[] memory cards = new string[](5);
        cards[0] = "AsKs"; // player1 wins
        cards[1] = "QhQd"; // player2 wins
        cards[2] = "JcJh"; // player3 wins
        cards[3] = "";
        cards[4] = "";

        uint256[] memory winners = new uint256[](3);
        winners[0] = 0; // player1
        winners[1] = 1; // player2
        winners[2] = 2; // player3

        smallPokerTable.revealShowdownResult(cards, winners);

        uint256 finalFeeCollectorBalance = CURRENCY.balanceOf(feeCollector);

        assertEq(finalFeeCollectorBalance - initialFeeCollectorBalance, 1);
        assertEq(finalFeeCollectorBalance - initialFeeCollectorBalance, expectedFees);
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
