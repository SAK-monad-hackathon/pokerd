// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPokerTable {
    error BigBlindPriceIsTooLow(uint256 price);
    error TableIsFull();
    error NotAPlayer();

    enum GamePhases {
        PreFlop,
        Flop,
        Turn,
        River
    }
}
