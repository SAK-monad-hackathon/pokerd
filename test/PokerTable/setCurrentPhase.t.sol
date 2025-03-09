// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

contract PokerTableSetCurrentPhaseTest is BaseFixtures {
    address player1 = address(1);
    address player2 = address(2);

    function setUp() public override {
        super.setUp();

        uint256 minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.bigBlindPrice();
        vm.startPrank(player1);
        currency.approve(address(pokerTable), minBuyIn);
        MockERC20(address(currency)).mint(player1, minBuyIn);
        pokerTable.joinTable(minBuyIn, 0);
        vm.stopPrank();

        vm.startPrank(player2);
        currency.approve(address(pokerTable), minBuyIn);
        MockERC20(address(currency)).mint(player2, minBuyIn);
        pokerTable.joinTable(minBuyIn, 1);
        vm.stopPrank();

        // sanity check
        assertEq(pokerTable.playerCount(), 2);
    }

    function test_defaultPhase() public view {
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
    }

    function test_setCurrentPhase() public {
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);

        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForDealer));
    }

    function test_setCurrentPhaseToWaitingForDealerIsAllowedFromAnyState() public {
        // from `WaitingForPlayers`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);

        // from `PreFlop`
        goToPhase(IPokerTable.GamePhases.PreFlop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);

        // from `Flop`
        goToPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);

        // from `Turn`
        goToPhase(IPokerTable.GamePhases.Turn);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);

        // from `River`
        goToPhase(IPokerTable.GamePhases.River);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);
    }

    function test_setCurrentPhaseToWaitingForPlayersIsAllowedFromAnyState() public {
        // from `WaitingForDealer`
        assertEq(uint256(pokerTable.currentPhase()), uint256(IPokerTable.GamePhases.WaitingForPlayers));
        goToPhase(IPokerTable.GamePhases.WaitingForDealer);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `PreFlop`
        goToPhase(IPokerTable.GamePhases.PreFlop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `Flop`
        goToPhase(IPokerTable.GamePhases.Flop);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `Turn`
        goToPhase(IPokerTable.GamePhases.Turn);
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForPlayers);

        // from `River`
        goToPhase(IPokerTable.GamePhases.River);
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
        pokerTable.setCurrentPhase(IPokerTable.GamePhases.WaitingForDealer);
    }
}
