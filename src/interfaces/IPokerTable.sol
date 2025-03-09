// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPokerTable {
    error BigBlindPriceIsTooLow(uint256 price);
    error TableIsFull();
    error NotAPlayer();
    error SkippingPhasesIsNotAllowed();
    error NotEnoughPlayers();
    error InvalidBuyIn();
    error OccupiedSeat();

    enum GamePhases {
        WaitingForPlayers,
        WaitingForDealer,
        PreFlop,
        WaitingForFlop,
        Flop,
        WaitingForTurn,
        Turn,
        WaitingForRiver,
        River,
        WaitingForResult
    }
}
