// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

/**
 * @notice Test case to test several gameplay scenarios and make sure a round can start and end properly in different scenarios
 */
contract PokerTableGameplayPreFlopCallsAndRestIsChecksToShowdownTest is BaseFixtures {
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

    function test_playersCallsBBAndCheckToShowdown() public {
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

        // p2 calls
        vm.startPrank(p2);
        pokerTable.bet(pokerTable.BIG_BLIND_PRICE());
        vm.stopPrank();
        assertTrue(pokerTable.isPlayerIndexInRound(2));
        assertEq(pokerTable.playerAmountInPot(p2), pokerTable.BIG_BLIND_PRICE(), "playerAmountInPot p2");
        assertEq(pokerTable.highestBettorIndex(), 1, "highestBettorIndex");

        // p3 calls
        vm.startPrank(p3);
        pokerTable.bet(pokerTable.BIG_BLIND_PRICE());
        vm.stopPrank();
        assertTrue(pokerTable.isPlayerIndexInRound(3));
        assertEq(pokerTable.playerAmountInPot(p3), pokerTable.BIG_BLIND_PRICE(), "playerAmountInPot p3");
        assertEq(pokerTable.highestBettorIndex(), 1, "highestBettorIndex");

        // p4 calls
        vm.startPrank(p4);
        pokerTable.bet(pokerTable.BIG_BLIND_PRICE());
        vm.stopPrank();
        assertTrue(pokerTable.isPlayerIndexInRound(4));
        assertEq(pokerTable.playerAmountInPot(p4), pokerTable.BIG_BLIND_PRICE(), "playerAmountInPot p4");
        assertEq(pokerTable.highestBettorIndex(), 1, "highestBettorIndex");

        // p0 calls
        vm.startPrank(p0);
        pokerTable.bet(pokerTable.SMALL_BLIND_PRICE());
        vm.stopPrank();
        assertTrue(pokerTable.isPlayerIndexInRound(0));
        assertEq(pokerTable.playerAmountInPot(p0), pokerTable.BIG_BLIND_PRICE(), "playerAmountInPot p0");
        assertEq(pokerTable.highestBettorIndex(), 2, "trick to advance pre-flop phase");
        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.PreFlop, "phase");

        // action should go back to p1 (BB) before moving forward
        // p1 checks
        vm.startPrank(p1);
        pokerTable.bet(0);
        vm.stopPrank();
        assertTrue(pokerTable.isPlayerIndexInRound(0));
        assertEq(pokerTable.playerAmountInPot(p0), pokerTable.BIG_BLIND_PRICE(), "playerAmountInPot p0");
        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForFlop, "phase WaitingForFlop");
        assertEq(pokerTable.currentBettorIndex(), 0, "current bettor index");

        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Flop, "AsAcAh");

        // all players check starting from p0 (sb)
        for (uint160 i = 0; i < 5; i++) {
            vm.prank(address(i + 1));
            pokerTable.bet(0);
        }

        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForTurn, "phase WaitingForTurn");
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.Turn, "Ks");

        // all players check starting from p0 (sb)
        for (uint160 i = 0; i < 5; i++) {
            vm.prank(address(i + 1));
            pokerTable.bet(0);
        }

        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForRiver, "phase WaitingForRiver");
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.River, "Kh");

        // all players check starting from p0 (sb)
        for (uint160 i = 0; i < 5; i++) {
            vm.prank(address(i + 1));
            pokerTable.bet(0);
        }

        assertEq(pokerTable.currentPhase(), IPokerTable.GamePhases.WaitingForResult, "phase WaitingForResult");
    }
}
