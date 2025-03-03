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
    }
}
