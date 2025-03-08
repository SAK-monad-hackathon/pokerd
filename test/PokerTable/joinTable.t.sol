// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin-contracts-5/interfaces/draft-IERC6093.sol";

import {IPokerTable} from "../../src/interfaces/IPokerTable.sol";
import {PokerTable} from "../../src/PokerTable.sol";

import {BaseFixtures} from "../utils/BaseFixtures.sol";
import {MockERC20} from "../utils/MockERC20.sol";

contract PokerTableJoinTableTest is BaseFixtures {
    uint256 minBuyIn;
    uint256 maxBuyIn;

    function setUp() public override {
        super.setUp();

        minBuyIn = pokerTable.MIN_BUY_IN_BB() * pokerTable.bigBlindPrice();
        maxBuyIn = pokerTable.MAX_BUY_IN_BB() * pokerTable.bigBlindPrice();
    }

    function test_playerCanJoin() public {
        uint256 playerBalanceBefore = currency.balanceOf(address(this));
        pokerTable.joinTable(minBuyIn);
        assertEq(currency.balanceOf(address(pokerTable)), minBuyIn);
        assertEq(currency.balanceOf(address(this)), playerBalanceBefore - minBuyIn);
        assertEq(pokerTable.playersBalance(address(this)), minBuyIn);

        assertTrue(pokerTable.players(address(this)));
        assertEq(pokerTable.playerCount(), 1);
    }

    function test_RevertWhen_tableIsFull() public {
        for (uint160 i = 1; i <= pokerTable.MAX_PLAYERS(); i++) {
            vm.startPrank(address(bytes20(i)));
            currency.approve(address(pokerTable), minBuyIn);
            MockERC20(address(currency)).mint(address(bytes20(i)), minBuyIn);
            pokerTable.joinTable(minBuyIn);
            vm.stopPrank();
        }

        // sanity check
        assertEq(pokerTable.playerCount(), pokerTable.MAX_PLAYERS());

        vm.expectRevert(IPokerTable.TableIsFull.selector);
        pokerTable.joinTable(minBuyIn);
    }

    function test_RevertWhen_buyInTooLow() public {
        vm.expectRevert(IPokerTable.InvalidBuyIn.selector);
        pokerTable.joinTable(minBuyIn - 1);
    }

    function test_RevertWhen_buyInTooHigh() public {
        vm.expectRevert(IPokerTable.InvalidBuyIn.selector);
        pokerTable.joinTable(maxBuyIn + 1);
    }

    function test_RevertWhen_notEnoughTokens() public {
        vm.startPrank(address(4242));
        currency.approve(address(pokerTable), type(uint256).max);
        MockERC20(address(currency)).mint(address(4242), maxBuyIn - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(4242), maxBuyIn - 1, maxBuyIn
            )
        );
        pokerTable.joinTable(maxBuyIn);
    }
}
