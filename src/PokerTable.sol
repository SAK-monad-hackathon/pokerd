// SPDX-License-Identifier: BUSL
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "./interfaces/IPokerTable.sol";

contract PokerTable is IPokerTable {
    /* -------------------------------- Constants ------------------------------- */

    uint8 public constant MAX_PLAYERS = 5;

    /* ------------------------------- Immutables ------------------------------- */

    IERC20 public immutable currency;
    uint256 public immutable bigBlindPrice;
    uint256 public immutable smallBlindPrice;

    /* ----------------------------- State Variables ---------------------------- */

    mapping(address => bool) public players;
    uint256 public playerCount;

    constructor(IERC20 _currency, uint256 _bigBlindPrice) {
        currency = _currency;

        require(_bigBlindPrice > 1, BigBlindPriceIsTooLow(_bigBlindPrice));
        bigBlindPrice = _bigBlindPrice;
        // rounding down is expected here
        smallBlindPrice = _bigBlindPrice / 2;
    }

    function joinTable() external {
        require(playerCount < MAX_PLAYERS, TableIsFull());

        players[msg.sender] = true;
        ++playerCount;
    }

    function leaveTable() external {
        require(players[msg.sender], NotAPlayer());

        players[msg.sender] = false;
        --playerCount;
    }
}
