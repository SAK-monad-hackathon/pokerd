// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

contract SimpleAllInTest is BaseFixtures {
    uint256 bbAmount;

    function setUp() public override {
        super.setUp();

        bbAmount = pokerTable.BIG_BLIND_PRICE();

        // Give players tokens
        MockERC20(address(CURRENCY)).mint(player1, 50 ether);
        MockERC20(address(CURRENCY)).mint(player2, 80 ether);

        vm.prank(player1);
        CURRENCY.approve(address(pokerTable), type(uint256).max);
        vm.prank(player2);
        CURRENCY.approve(address(pokerTable), type(uint256).max);

        // Players join
        vm.prank(player1);
        pokerTable.joinTable(50 ether, 0);
        vm.prank(player2);
        pokerTable.joinTable(80 ether, 1);
    }

    function test_simpleAllIn() public {
        // Start the round
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer, "");
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.PreFlop, "");

        // player1 should be the current bettor (after BB)
        // But after blinds, player1 has paid SB and player2 has paid BB
        // Current bettor should be the player after BB
        uint256 currentBettor = pokerTable.currentBettorIndex();
        address currentBettorAddress = pokerTable.playerIndices(currentBettor);
        uint256 currentBalance = pokerTable.playersBalance(currentBettorAddress);

        // Current player goes all-in with remaining balance
        vm.prank(currentBettorAddress);
        pokerTable.bet(currentBalance);

        assertTrue(pokerTable.isPlayerAllIn(currentBettorAddress));

        // Now it should be the other player's turn
        currentBettor = pokerTable.currentBettorIndex();
        currentBettorAddress = pokerTable.playerIndices(currentBettor);
        currentBalance = pokerTable.playersBalance(currentBettorAddress);

        // Second player goes all-in with remaining balance
        vm.prank(currentBettorAddress);
        pokerTable.bet(currentBalance);

        assertTrue(pokerTable.isPlayerAllIn(currentBettorAddress));

        // The phase should advance since both players are all-in
        assertTrue(uint256(pokerTable.currentPhase()) > uint256(IPokerTable.GamePhases.PreFlop));
    }
}
