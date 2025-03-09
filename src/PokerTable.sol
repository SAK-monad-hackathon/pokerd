// SPDX-License-Identifier: BUSL
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts-5/access/Ownable.sol";

import {IPokerTable} from "./interfaces/IPokerTable.sol";

contract PokerTable is IPokerTable, Ownable {
    using SafeERC20 for IERC20;

    /* -------------------------------- Constants ------------------------------- */

    uint8 public constant MAX_PLAYERS = 5;

    /// @notice Minimum buy-in (in Big Blinds)
    uint8 public constant MIN_BUY_IN_BB = 40;

    /// @notice Maximum buy-in (in Big Blinds)
    uint8 public constant MAX_BUY_IN_BB = 100;

    /// @notice How many seconds needs to elapse before a player is force-folded
    uint16 public constant PLAYER_TIMEOUT_AFTER = 30;

    /* ------------------------------- Immutables ------------------------------- */

    IERC20 public immutable CURRENCY;
    uint256 public immutable BIG_BLIND_PRICE;
    uint256 public immutable SMALL_BLIND_PRICE;

    /* ----------------------------- State Variables ---------------------------- */

    mapping(address => bool) public players;
    mapping(uint256 => address) public playerIndices;
    mapping(address => uint256) public reversePlayerIndices;
    mapping(address => uint256) public playersBalance;
    mapping(uint256 => bool) public isPlayerIndexInRound;
    uint256 public playerCount;
    uint256 public playersLeftInRoundCount;
    uint256 public playerIndexWithBigBlind;
    GamePhases public currentPhase;
    uint256 public currentRoundId;
    mapping(uint256 => RoundData) public roundData;
    mapping(address => uint256) public playerAmountInPot;
    uint256 public currentBettorIndex;
    uint256 public currentPot;
    uint256 public highestBettorIndex;
    uint256 public amountToCall;

    constructor(IERC20 _currency, uint256 _bigBlindPrice) Ownable(msg.sender) {
        CURRENCY = _currency;

        require(_bigBlindPrice > 1, BigBlindPriceIsTooLow(_bigBlindPrice));
        BIG_BLIND_PRICE = _bigBlindPrice;
        // rounding down is expected here
        SMALL_BLIND_PRICE = _bigBlindPrice / 2;
    }

    function joinTable(uint256 _buyIn, uint256 _indexOnTable) external {
        uint256 _bigBlindPrice = BIG_BLIND_PRICE;
        require(playerCount < MAX_PLAYERS, TableIsFull());
        require(playerIndices[_indexOnTable] == address(0), OccupiedSeat());
        require(_buyIn >= MIN_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());
        require(_buyIn <= MAX_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());

        players[msg.sender] = true;
        playerIndices[_indexOnTable] = msg.sender;
        reversePlayerIndices[msg.sender] = _indexOnTable;
        ++playerCount;
        playersBalance[msg.sender] = _buyIn;

        CURRENCY.safeTransferFrom(msg.sender, address(this), _buyIn);

        emit PlayerJoined(msg.sender, _buyIn, _indexOnTable);
    }

    function leaveTable() external {
        require(players[msg.sender], NotAPlayer());

        players[msg.sender] = false;
        uint256 _playerIndex = reversePlayerIndices[msg.sender];
        reversePlayerIndices[msg.sender] = 0;
        playerIndices[_playerIndex] = address(0);
        --playerCount;
        uint256 _playerBalance = playersBalance[msg.sender];
        playersBalance[msg.sender] = 0;

        if (_playerBalance > 0) {
            CURRENCY.transfer(msg.sender, _playerBalance);
        }

        emit PlayerLeft(msg.sender, _playerBalance, _playerIndex);
    }

    function setCurrentPhase(GamePhases _newPhase, string calldata _cardsToReveal) external onlyOwner {
        GamePhases _currentPhase = currentPhase;
        if (_newPhase != GamePhases.WaitingForDealer && _newPhase != GamePhases.WaitingForPlayers) {
            require(uint256(_newPhase) == uint256(_currentPhase) + 1, SkippingPhasesIsNotAllowed());
        } else if (_currentPhase == GamePhases.WaitingForPlayers && _newPhase == GamePhases.WaitingForDealer) {
            require(playerCount > 1, NotEnoughPlayers());
        }

        roundData[currentRoundId].cardsRevealed = string.concat(roundData[currentRoundId].cardsRevealed, _cardsToReveal);

        _setCurrentPhase(_newPhase);
    }

    function bet(uint256 _amount) external {
        uint256 _currentBettorIndex = currentBettorIndex;
        require(_currentBettorIndex == reversePlayerIndices[msg.sender], NotTurnOfPlayer());
        require(_amount <= playersBalance[msg.sender], NotEnoughBalance());

        uint256 _playerBets = playerAmountInPot[msg.sender];
        uint256 _minBet = amountToCall - _playerBets;
        require(_amount >= _minBet, BetTooSmall());

        // If player raise, set him as highest bettor
        if (_playerBets + _amount > amountToCall) {
            amountToCall = _playerBets + _amount;
            highestBettorIndex = _currentBettorIndex;
        }

        playersBalance[msg.sender] -= _amount;
        playerAmountInPot[msg.sender] = _playerBets + _amount;
        currentPot += _amount;
        uint256 _nextBettorIndex = _findNextBettor(_currentBettorIndex);
        currentBettorIndex = _nextBettorIndex;

        // if the next player to bet is the highest bettor, all the players either folded or called.
        // which means the current phase ended, and the next phase can begin.
        if (_nextBettorIndex == highestBettorIndex) {
            _setCurrentPhase(GamePhases(uint256(currentPhase) + 1));
        }

        emit PlayerBet(msg.sender, _currentBettorIndex, _amount);
    }

    function fold() external {
        uint256 playerIndex = reversePlayerIndices[msg.sender];
        require(currentBettorIndex == playerIndex, NotTurnOfPlayer());
        require(isPlayerIndexInRound[playerIndex], PlayerNotInHand());

        _fold(playerIndex);
    }

    function revealShowdownResult(RoundResult[] memory gains) external onlyOwner {
        require(currentPhase == GamePhases.WaitingForResult, InvalidState(currentPhase, GamePhases.WaitingForResult));
        require(gains.length == MAX_PLAYERS, InvalidGains());
        int256 gainsAccumulator;
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address _player = playerIndices[i];
            int256 _playerGains = gains[i].gains;
            require(_playerGains >= 0, InvalidGains());
            gainsAccumulator += _playerGains;

            if (_playerGains > 0) {
                playersBalance[_player] += uint256(_playerGains);
            }
            roundData[currentRoundId].results[i].gains = _playerGains - int256(playerAmountInPot[_player]);
        }

        require(uint256(gainsAccumulator) == currentPot, InvalidGains());

        emit ShowdownEnded(gains, currentPot, roundData[currentRoundId].cardsRevealed);

        _setCurrentPhase(GamePhases.WaitingForDealer);
    }

    function timeoutCurrentPlayer() external onlyOwner {
        _fold(currentBettorIndex);
    }

    function cancelCurrentRound() external onlyOwner {
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address player = playerIndices[i];
            playersBalance[player] += playerAmountInPot[player];
        }

        _setCurrentPhase(GamePhases.WaitingForDealer);
    }

    /* ---------------------------- Private Functions --------------------------- */

    function _setCurrentPhase(GamePhases _newPhase) private {
        GamePhases _previousPhase = currentPhase;
        if (_newPhase == GamePhases.WaitingForDealer) {
            _resetGameState();
            if (playerCount <= 1) {
                currentPhase = GamePhases.WaitingForPlayers;
                emit PhaseChanged(_newPhase, _previousPhase);
                return;
            }

            ++currentRoundId;

            // assign blinds and make players pay them
            // TODO handle cases where players don't have enough tokens to pay the blinds
            (uint256 _SBIndex, uint256 _BBIndex) = _assignNextBlinds();
            address _bb = playerIndices[_BBIndex];
            currentPot += BIG_BLIND_PRICE + (BIG_BLIND_PRICE / 2);
            playerAmountInPot[_bb] = BIG_BLIND_PRICE;
            playersBalance[_bb] -= BIG_BLIND_PRICE;

            address _sb = playerIndices[_SBIndex];
            if (_sb != address(0)) {
                playerAmountInPot[_sb] = BIG_BLIND_PRICE / 2;
                playersBalance[_sb] -= BIG_BLIND_PRICE / 2;
            }

            highestBettorIndex = _BBIndex;
            currentBettorIndex = _findNextBettor(_BBIndex);
            amountToCall = BIG_BLIND_PRICE;
        } else if (_newPhase == GamePhases.WaitingForPlayers) {
            _resetGameState();
        }

        currentPhase = _newPhase;

        emit PhaseChanged(_newPhase, _previousPhase);
    }

    function _fold(uint256 playerIndex) private {
        uint256 _playersLeftInRoundCount = playersLeftInRoundCount;
        isPlayerIndexInRound[playerIndex] = false;
        playersLeftInRoundCount = --_playersLeftInRoundCount;

        emit PlayerFolded(playerIndex);

        if (_playersLeftInRoundCount == 1) {
            address player = playerIndices[highestBettorIndex];
            playersBalance[player] += currentPot;
            emit PlayerWonWithoutShowdown(player, highestBettorIndex, currentPot, currentPhase);
            _setCurrentPhase(GamePhases.WaitingForDealer);
        } else {
            currentBettorIndex = _findNextBettor(playerIndex);
        }
    }

    function _assignNextBlinds() private returns (uint256 SBIndex_, uint256 BBIndex_) {
        uint256 _currentBB = playerIndexWithBigBlind;
        SBIndex_ = _currentBB;
        BBIndex_ = _currentBB + 1;

        while (playerIndices[BBIndex_] == address(0) || playersBalance[playerIndices[BBIndex_]] == 0) {
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
        while (
            (!isPlayerIndexInRound[nextPlayerIndex_] || playersBalance[playerIndices[nextPlayerIndex_]] == 0)
                && nextPlayerIndex_ != _currentBettorIndex
        ) {
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

            playerAmountInPot[player] = 0;
            isPlayerIndexInRound[i] = true;
        }

        playersLeftInRoundCount = playerCount;
        amountToCall = 0;
        currentPot = 0;
    }
}
