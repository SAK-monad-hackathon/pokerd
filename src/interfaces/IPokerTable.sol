// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

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
    error PlayerStillPlaying();
    error PlayerNotInHand();
    error BetTooSmall();
    error InvalidBetAmount();
    error NotEnoughBalance();
    error InvalidShowdownResults();

    event PlayerJoined(address indexed player, uint256 buyIn, uint256 indexOnTable, GamePhases currentPhase);
    event PlayerLeft(address indexed player, uint256 amountWithdrawn, uint256 indexOnTable, GamePhases currentPhase);
    event PhaseChanged(GamePhases previousPhase, GamePhases newPhase);
    event PlayerBet(address indexed player, uint256 indexOnTable, uint256 betAmount);
    event PlayerFolded(uint256 indexOnTable);
    event PlayerWonWithoutShowdown(address indexed winner, uint256 indexOnTable, uint256 pot, GamePhases phase);
    event ShowdownEnded(PlayerResult[] playersData, uint256 pot, string communityCards);

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

    struct PlayerResult {
        int256 gains;
        string cards;
    }

    struct RoundData {
        string communityCards;
        PlayerResult[] results;
    }

    function MAX_PLAYERS() external view returns (uint8);
    function MIN_BUY_IN_BB() external view returns (uint8);
    function MAX_BUY_IN_BB() external view returns (uint8);
    function PLAYER_TIMEOUT_AFTER() external view returns (uint16);

    function CURRENCY() external view returns (IERC20);
    function BIG_BLIND_PRICE() external view returns (uint256);
    function SMALL_BLIND_PRICE() external view returns (uint256);

    function players(address player) external view returns (bool);
    function playerIndices(uint256 index) external view returns (address);
    function reversePlayerIndices(address player) external view returns (uint256);
    function isPlayerIndexInRound(uint256 index) external view returns (bool);
    function playerCount() external view returns (uint256);
    function playersLeftInRoundCount() external view returns (uint256);
    function playerIndexWithBigBlind() external view returns (uint256);
    function currentPhase() external view returns (GamePhases);
    function currentRoundId() external view returns (uint256);
    // function roundData(uint256 roundId) external view returns (RoundData memory);
    function playerAmountInPot(address player) external view returns (uint256);
    function currentBettorIndex() external view returns (uint256);
    function currentPot() external view returns (uint256);
    function highestBettorIndex() external view returns (uint256);
    function amountToCall() external view returns (uint256);

    function joinTable(uint256 _buyIn, uint256 _indexOnTable) external;
    function leaveTable() external;
    function setCurrentPhase(GamePhases _newPhase, string calldata _cardsToReveal) external;
    function bet(uint256 _amount) external;
    function fold() external;
    function revealShowdownResult(string[] calldata _cards, uint256[] calldata _winners) external;
    function timeoutCurrentPlayer() external;
    function cancelCurrentRound() external;
}
