// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPokerTable {
    error BigBlindPriceIsTooLow(uint256 price);
    error TableIsFull();
    error NotAPlayer();
    error SkippingPhasesIsNotAllowed();
    error InvalidState(GamePhases current, GamePhases required);
    error NotEnoughPlayers();
    error InvalidBuyIn();
    error OccupiedSeat();
    error NotTurnOfPlayer();
    error PlayerNotInHand();
    error BetTooSmall();
    error InvalidBetAmount();
    error NotEnoughBalance();
    error InvalidGains();

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

    struct RoundResult {
        int256 gains;
        string cards;
    }

    struct RoundData {
        string cardsRevealed;
        RoundResult[] results;
    }
}
