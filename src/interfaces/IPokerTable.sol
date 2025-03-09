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

    event PlayerJoined(address indexed player, uint256 buyIn, uint256 indexOnTable);
    event PlayerLeft(address indexed player, uint256 amountWithdrawn, uint256 indexOnTable);
    event PhaseChanged(GamePhases previousPhase, GamePhases newPhase);
    event PlayerBet(address indexed player, uint256 indexOnTable, uint256 betAmount);
    event PlayerFolded(uint256 indexOnTable);
    event PlayerWonWithoutShowdown(address indexed winner, uint256 indexOnTable, uint256 pot, GamePhases phase);
    event ShowdownEnded(RoundResult[] playersData, uint256 pot, string communityCards);

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
        string communityCards;
        RoundResult[] results;
    }
}
