// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

/**
 * @notice Test case to test several gameplay scenarios and make sure a round can start and end properly in different scenarios
 */
contract PokerTableGameplayPreFlopBetsThenFoldsTest is BaseFixtures {
    uint256 minBuyIn;
    uint256 maxBuyIn;
    uint256 sbAmount;
    uint256 bbAmount;
    address dealer = address(this);
    address p0 = address(1);
    address p1 = address(2);
    address p2 = address(3);
    address p3 = address(4);
    address p4 = address(5);

    function setUp() public override {
        super.setUp();

        minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.BIG_BLIND_PRICE();
        maxBuyIn = pokerTable.MAX_BUY_IN_BB() * pokerTable.BIG_BLIND_PRICE();
        bbAmount = pokerTable.BIG_BLIND_PRICE();
        sbAmount = bbAmount / 2;

        MockERC20(address(CURRENCY)).mint(p0, maxBuyIn);
        MockERC20(address(CURRENCY)).mint(p1, maxBuyIn);
        MockERC20(address(CURRENCY)).mint(p2, maxBuyIn);
        MockERC20(address(CURRENCY)).mint(p3, maxBuyIn);
        MockERC20(address(CURRENCY)).mint(p4, maxBuyIn);

        vm.prank(p0);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(p1);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(p2);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(p3);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(p4);
        CURRENCY.approve(address(pokerTable), type(uint256).max);

        // sanity check
        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForPlayers);
    }

    function test_playersBetsThenFold() public {
        vm.prank(p0);
        pokerTable.joinTable(maxBuyIn, 0);
        vm.prank(p1);
        pokerTable.joinTable(maxBuyIn, 1);
        vm.prank(p2);
        pokerTable.joinTable(maxBuyIn, 2);
        vm.prank(p3);
        pokerTable.joinTable(maxBuyIn, 3);
        vm.prank(p4);
        pokerTable.joinTable(maxBuyIn, 4);

        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");

        assertEq(pokerTable.highestBettorIndex(), 1, "highestBettorIndex");
        assertEq(pokerTable.currentBettorIndex(), 2, "currentBettorIndex");
        assertEq(pokerTable.currentPot(), bbAmount + sbAmount);
        assertEq(pokerTable.playerAmountInPot(p0), sbAmount, "playerAmountInPot p0");
        assertEq(pokerTable.playerAmountInPot(p1), bbAmount, "playerAmountInPot p1");
        assertEq(pokerTable.playerAmountInPot(p2), 0, "playerAmountInPot p2");
        assertEq(pokerTable.playerAmountInPot(p3), 0, "playerAmountInPot p3");
        assertEq(pokerTable.playerAmountInPot(p4), 0, "playerAmountInPot p4");

        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");

        // p2 bets 3 BB
        vm.startPrank(p2);
        pokerTable.bet(pokerTable.BIG_BLIND_PRICE() * 3);
        vm.stopPrank();
        assertTrue(pokerTable.isPlayerIndexInRound(2));
        assertEq(pokerTable.playerAmountInPot(p2), pokerTable.BIG_BLIND_PRICE() * 3, "playerAmountInPot p2");
        assertEq(pokerTable.highestBettorIndex(), 2, "highestBettorIndex");

        // p3 folds
        assertEq(pokerTable.currentBettorIndex(), 3, "currentBettorIndex");
        vm.prank(p3);
        pokerTable.fold();
        assertFalse(pokerTable.isPlayerIndexInRound(3));
        assertEq(pokerTable.playersLeftInRoundCount(), 4);

        // p4 bets 9 BB
        vm.startPrank(p4);
        pokerTable.bet(pokerTable.BIG_BLIND_PRICE() * 9);
        vm.stopPrank();
        assertEq(pokerTable.highestBettorIndex(), 4, "highestBettorIndex");

        // p0 folds
        vm.prank(p0);
        pokerTable.fold();
        assertFalse(pokerTable.isPlayerIndexInRound(0));
        assertEq(pokerTable.playersLeftInRoundCount(), 3);

        // p1 folds
        vm.prank(p1);
        pokerTable.fold();
        assertFalse(pokerTable.isPlayerIndexInRound(1));
        assertEq(pokerTable.playersLeftInRoundCount(), 2);

        // p2 all-in
        vm.startPrank(p2);
        pokerTable.bet(pokerTable.playersBalance(p2));
        vm.stopPrank();
        assertEq(pokerTable.playersBalance(p2), 0);
        assertTrue(pokerTable.isPlayerIndexInRound(2));

        // p4 folds
        assertEq(pokerTable.currentBettorIndex(), 4, "currentBettorIndex");
        vm.prank(p4);
        pokerTable.fold();

        // reset should happen here
        assertEq(pokerTable.playersBalance(p0), maxBuyIn - sbAmount);
        assertEq(pokerTable.playersBalance(p1), maxBuyIn - bbAmount, "p1");
        assertEq(pokerTable.playersBalance(p2), maxBuyIn + pokerTable.BIG_BLIND_PRICE() * 10 + sbAmount, "p2");
        assertEq(pokerTable.playersBalance(p3), maxBuyIn, "p3");
        assertEq(pokerTable.playersBalance(p4), maxBuyIn - pokerTable.BIG_BLIND_PRICE() * 9);

        // state should be back to WaitingForPlayers
        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForPlayers);

        // start next round
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");

        assertEq(pokerTable.currentRoundId(), 1, "round ID shoudl equal 1");
        assertEq(pokerTable.playersLeftInRoundCount(), 5);

        // all players should be back in round
        assertTrue(pokerTable.isPlayerIndexInRound(0));
        assertTrue(pokerTable.isPlayerIndexInRound(1));
        assertTrue(pokerTable.isPlayerIndexInRound(2));
        assertTrue(pokerTable.isPlayerIndexInRound(3));
        assertTrue(pokerTable.isPlayerIndexInRound(4));

        // blinds should have rotated
        assertEq(pokerTable.highestBettorIndex(), 2);
        assertEq(pokerTable.currentBettorIndex(), 3, "currentBettorIndex");
    }
}
