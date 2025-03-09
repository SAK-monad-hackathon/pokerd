// SPDX-License-Identifier: BUSL
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5/token/ERC20/utils/SafeERC20.sol";

import {IPokerTable} from "./interfaces/IPokerTable.sol";

contract PokerTable is IPokerTable {
    using SafeERC20 for IERC20;

    /* -------------------------------- Constants ------------------------------- */

    uint8 public constant MAX_PLAYERS = 5;

    /// @notice Minimum buy-in (in Big Blinds)
    uint8 public constant MIN_BUY_IN_BB = 40;

    /// @notice Maximum buy-in (in Big Blinds)
    uint8 public constant MAX_BUY_IN_BB = 100;

    /* ------------------------------- Immutables ------------------------------- */

    IERC20 public immutable currency;
    uint256 public immutable bigBlindPrice;
    uint256 public immutable smallBlindPrice;

    /* ----------------------------- State Variables ---------------------------- */

    mapping(address => bool) public players;
    mapping(uint256 => address) public playerIndices;
    mapping(address => uint256) public reversePlayerIndices;
    mapping(address => uint256) public playersBalance;
    mapping(uint256 => bool) public isPlayerIndexInHand;
    uint256 public playerCount;
    uint256 public playersLeftInHandCount;
    uint256 public playerIndexWithBigBlind;
    GamePhases public currentPhase;
    mapping(address => uint256) public playerBets;
    uint256 public currentBettorIndex;
    uint256 public currentPot;
    uint256 public highestBettorIndex;
    uint256 public amountToCall;

    constructor(IERC20 _currency, uint256 _bigBlindPrice) {
        currency = _currency;

        require(_bigBlindPrice > 1, BigBlindPriceIsTooLow(_bigBlindPrice));
        bigBlindPrice = _bigBlindPrice;
        // rounding down is expected here
        smallBlindPrice = _bigBlindPrice / 2;
    }

    function joinTable(uint256 _buyIn, uint256 _indexOnTable) external {
        uint256 _bigBlindPrice = bigBlindPrice;
        require(playerCount < MAX_PLAYERS, TableIsFull());
        require(playerIndices[_indexOnTable] == address(0), OccupiedSeat());
        require(_buyIn >= MIN_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());
        require(_buyIn <= MAX_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());

        players[msg.sender] = true;
        playerIndices[_indexOnTable] = msg.sender;
        reversePlayerIndices[msg.sender] = _indexOnTable;
        ++playerCount;
        playersBalance[msg.sender] = _buyIn;

        currency.safeTransferFrom(msg.sender, address(this), _buyIn);
    }

    function leaveTable() external {
        require(players[msg.sender], NotAPlayer());

        players[msg.sender] = false;
        uint256 playerIndex = reversePlayerIndices[msg.sender];
        reversePlayerIndices[msg.sender] = 0;
        playerIndices[playerIndex] = address(0);
        --playerCount;
        uint256 playerBalance = playersBalance[msg.sender];
        playersBalance[msg.sender] = 0;

        if (playerBalance > 0) {
            currency.transfer(msg.sender, playerBalance);
        }
    }

    // TODO should only be callable by dealer
    function setCurrentPhase(GamePhases _newPhase) external {
        GamePhases _currentPhase = currentPhase;
        if (_newPhase != GamePhases.WaitingForDealer && _newPhase != GamePhases.WaitingForPlayers) {
            require(uint256(_newPhase) == uint256(_currentPhase) + 1, SkippingPhasesIsNotAllowed());
        } else if (_currentPhase == GamePhases.WaitingForPlayers && _newPhase == GamePhases.WaitingForDealer) {
            require(playerCount > 1, NotEnoughPlayers());
        }

        _setCurrentPhase(_newPhase);
    }

    function bet(uint256 _amount) external {
        uint256 _currentBettorIndex = currentBettorIndex;
        require(_currentBettorIndex == reversePlayerIndices[msg.sender], NotTurnOfPlayer());
        require(_amount <= playersBalance[msg.sender], NotEnoughBalance());

        uint256 _playerBets = playerBets[msg.sender];
        uint256 _minBet = amountToCall - _playerBets;
        require(_amount >= _minBet, BetTooSmall());

        // If player raise, set him as highest bettor
        if (_playerBets + _amount > amountToCall) {
            amountToCall = _playerBets + _amount;
            highestBettorIndex = _currentBettorIndex;
        }

        playerBets[msg.sender] = _playerBets + _amount;
        currentPot += _amount;
        uint256 _nextBettorIndex = _findNextBettor(_currentBettorIndex);
        currentBettorIndex = _nextBettorIndex;

        // if the next player to bet is the highest bettor, all the players either folded or called.
        // which means the current phase ended, and the next phase can begin.
        if (_nextBettorIndex == highestBettorIndex) {
            _setCurrentPhase(GamePhases(uint256(currentPhase) + 1));
        }
    }

    function fold() external {
        uint256 playerIndex = reversePlayerIndices[msg.sender];
        require(currentBettorIndex == playerIndex, NotTurnOfPlayer());
        require(isPlayerIndexInHand[playerIndex], PlayerNotInHand());

        uint256 _playersLeftInHandCount = playersLeftInHandCount;
        isPlayerIndexInHand[playerIndex] = false;
        playersLeftInHandCount = --_playersLeftInHandCount;

        // TODO if last player fold, highest bettor won
        if (_playersLeftInHandCount == 1) {
            playersBalance[playerIndices[highestBettorIndex]] += currentPot;
            _setCurrentPhase(GamePhases.WaitingForDealer);
        }
    }

    /* ---------------------------- Private Functions --------------------------- */
    function _setCurrentPhase(GamePhases _newPhase) private {
        if (_newPhase == GamePhases.WaitingForDealer) {
            _resetGameState();
            if (playerCount <= 1) {
                currentPhase = GamePhases.WaitingForPlayers;
                return;
            }

            // assign blinds and make players pay them
            // TODO handle cases where players don't have enough tokens to pay the blinds
            (uint256 _SBIndex, uint256 _BBIndex) = _assignNextBlinds();
            currentPot += bigBlindPrice + (bigBlindPrice / 2);
            playersBalance[playerIndices[_BBIndex]] -= bigBlindPrice;

            address _sb = playerIndices[_SBIndex];
            if (_sb != address(0)) {
                playerBets[_sb] = bigBlindPrice;
                playersBalance[_sb] -= bigBlindPrice / 2;
            }

            highestBettorIndex = _BBIndex;
            currentBettorIndex = _findNextBettor(_BBIndex);
            amountToCall = bigBlindPrice;
        } else if (_newPhase == GamePhases.WaitingForPlayers) {
            _resetGameState();
        }

        currentPhase = _newPhase;
    }

    function _assignNextBlinds() private returns (uint256 SBIndex_, uint256 BBIndex_) {
        uint256 _currentBB = playerIndexWithBigBlind;
        SBIndex_ = _currentBB;
        BBIndex_ = _currentBB + 1;

        while (playerIndices[BBIndex_] == address(0)) {
            if (BBIndex_ >= MAX_PLAYERS) {
                BBIndex_ = 0;
            } else {
                ++BBIndex_;
            }
        }

        playerIndexWithBigBlind = BBIndex_;
        return (SBIndex_, BBIndex_);
    }

    function _findNextBettor(uint256 _currentBettorIndex) private view returns (uint256 nextPlayerIndex_) {
        nextPlayerIndex_ = _currentBettorIndex + 1;
        while (!isPlayerIndexInHand[nextPlayerIndex_]) {
            if (nextPlayerIndex_ >= MAX_PLAYERS) {
                nextPlayerIndex_ = 0;
            } else {
                ++nextPlayerIndex_;
            }
        }
    }

    function _resetGameState() private {
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address player = playerIndices[i];
            if (player == address(0)) {
                continue;
            }

            playerBets[player] = 0;
            isPlayerIndexInHand[i] = true;
        }

        playersLeftInHandCount = playerCount;
        amountToCall = 0;
        currentPot = 0;
    }
}
