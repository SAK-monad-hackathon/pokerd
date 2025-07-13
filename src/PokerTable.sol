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
    mapping(address => bool) public isPlayerAllIn;
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
    address public feeCollector;

    constructor(IERC20 _currency, uint256 _bigBlindPrice) Ownable(msg.sender) {
        CURRENCY = _currency;

        require(_bigBlindPrice > 1, BigBlindPriceIsTooLow(_bigBlindPrice));
        BIG_BLIND_PRICE = _bigBlindPrice;
        // rounding down is expected here
        SMALL_BLIND_PRICE = _bigBlindPrice / 2;
    }

    function getRoundData(uint256 _roundId) external view returns (RoundData memory) {
        return roundData[_roundId];
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

        emit PlayerJoined(msg.sender, _buyIn, _indexOnTable, currentPhase);
    }

    function leaveTable() external {
        require(players[msg.sender], NotAPlayer());
        uint256 _playerIndex = reversePlayerIndices[msg.sender];
        // player should fold before trying to leave the table
        require(!isPlayerIndexInRound[_playerIndex], PlayerStillPlaying());

        players[msg.sender] = false;
        reversePlayerIndices[msg.sender] = 0;
        playerIndices[_playerIndex] = address(0);
        --playerCount;
        uint256 _playerBalance = playersBalance[msg.sender];
        playersBalance[msg.sender] = 0;

        if (_playerBalance > 0) {
            CURRENCY.safeTransfer(msg.sender, _playerBalance);
        }

        emit PlayerLeft(msg.sender, _playerBalance, _playerIndex, currentPhase);
    }

    function setCurrentPhase(GamePhases _newPhase, string calldata _cardsToReveal) external onlyOwner {
        GamePhases _currentPhase = currentPhase;
        if (_newPhase != GamePhases.WaitingForPlayers) {
            require(uint256(_newPhase) == uint256(_currentPhase) + 1, SkippingPhasesIsNotAllowed());
        }

        roundData[currentRoundId].communityCards =
            string.concat(roundData[currentRoundId].communityCards, _cardsToReveal);

        _setCurrentPhase(_newPhase);
    }

    function bet(uint256 _amount) external {
        uint256 _currentBettorIndex = currentBettorIndex;
        require(_currentBettorIndex == reversePlayerIndices[msg.sender], NotTurnOfPlayer());
        require(_amount <= playersBalance[msg.sender], NotEnoughBalance());

        uint256 _playerBets = playerAmountInPot[msg.sender];
        uint256 _minBet = amountToCall - _playerBets;
        uint256 _playerBalance = playersBalance[msg.sender];
        
        // Check if player is trying to bet less than minimum (unless going all-in)
        if (_amount < _minBet && _amount < _playerBalance) {
            revert BetTooSmall();
        }

        // Handle all-in scenario
        bool isAllIn = _amount == _playerBalance;
        if (isAllIn) {
            isPlayerAllIn[msg.sender] = true;
        }

        // If player raise (and not just calling), set him as highest bettor
        if (_playerBets + _amount > amountToCall) {
            amountToCall = _playerBets + _amount;
            highestBettorIndex = _currentBettorIndex;
        }

        playersBalance[msg.sender] -= _amount;
        playerAmountInPot[msg.sender] = _playerBets + _amount;
        currentPot += _amount;

        emit PlayerBet(msg.sender, _currentBettorIndex, _amount);

        uint256 _nextBettorIndex = _findNextBettorIndex(_currentBettorIndex);
        
        // Check if we should advance phase due to all-in situation
        if (isAllIn) {
            _checkAllInAdvancePhase(_nextBettorIndex);
        } else {
            currentBettorIndex = _nextBettorIndex;
            _advancePhaseIfNeeded(_nextBettorIndex);
        }
    }

    function fold() external {
        uint256 _playerIndex = reversePlayerIndices[msg.sender];
        require(currentBettorIndex == _playerIndex, NotTurnOfPlayer());
        require(isPlayerIndexInRound[_playerIndex], PlayerNotInHand());

        _fold(_playerIndex);

        if (currentPhase != GamePhases.WaitingForPlayers) {
            _advancePhaseIfNeeded(_playerIndex);
        }
    }

    function revealShowdownResult(string[] calldata _cards, uint256[] calldata _winners) external onlyOwner {
        require(currentPhase == GamePhases.WaitingForResult, InvalidState(currentPhase, GamePhases.WaitingForResult));
        require(_cards.length == MAX_PLAYERS, InvalidShowdownResults());
        require(_winners.length <= MAX_PLAYERS && _winners.length > 0, InvalidShowdownResults());
        
        // Initialize results array
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address _playerAddress = playerIndices[i];
            roundData[currentRoundId].results.push(
                PlayerResult({cards: _cards[i], gains: -int256(playerAmountInPot[_playerAddress])})
            );
        }

        // Calculate side pots
        SidePot[] memory sidePots = _calculateSidePots();
        
        // Store side pots in storage individually
        delete roundData[currentRoundId].sidePots;
        for (uint256 i = 0; i < sidePots.length; i++) {
            roundData[currentRoundId].sidePots.push(sidePots[i]);
        }

        // Distribute each side pot to winners eligible for that pot
        uint256 totalFees = 0;
        for (uint256 potIndex = 0; potIndex < sidePots.length; potIndex++) {
            SidePot memory pot = sidePots[potIndex];
            
            // Find winners eligible for this pot
            uint256 eligibleWinnersCount = 0;
            uint256[] memory eligibleWinners = new uint256[](pot.eligiblePlayers.length);
            
            for (uint256 i = 0; i < _winners.length; i++) {
                address winnerAddress = playerIndices[_winners[i]];
                
                // Check if this winner is eligible for this pot
                for (uint256 j = 0; j < pot.eligiblePlayers.length; j++) {
                    if (pot.eligiblePlayers[j] == winnerAddress) {
                        eligibleWinners[eligibleWinnersCount] = _winners[i];
                        eligibleWinnersCount++;
                        break;
                    }
                }
            }
            
            if (eligibleWinnersCount > 0) {
                uint256 amountPerWinner = pot.amount / eligibleWinnersCount;
                uint256 remainder = pot.amount % eligibleWinnersCount;
                totalFees += remainder;
                
                for (uint256 i = 0; i < eligibleWinnersCount; i++) {
                    uint256 winnerIndex = eligibleWinners[i];
                    address winnerAddress = playerIndices[winnerIndex];
                    roundData[currentRoundId].results[winnerIndex].gains += int256(amountPerWinner);
                    playersBalance[winnerAddress] += amountPerWinner;
                }
            } else {
                // If no eligible winners for this pot, it goes to fees
                totalFees += pot.amount;
            }
        }

        // Transfer collected fees
        if (totalFees > 0 && feeCollector != address(0)) {
            CURRENCY.safeTransfer(feeCollector, totalFees);
        }

        emit ShowdownEnded(roundData[currentRoundId].results, currentPot, roundData[currentRoundId].communityCards);

        _setCurrentPhase(GamePhases.WaitingForPlayers);
    }

    function timeoutCurrentPlayer() external onlyOwner {
        _fold(currentBettorIndex);
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    function cancelCurrentRound() external onlyOwner {
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address player = playerIndices[i];
            playersBalance[player] += playerAmountInPot[player];
        }

        _resetGameState();

        _setCurrentPhase(GamePhases.WaitingForPlayers);
    }

    function _checkAllInAdvancePhase(uint256 _nextBettorIndex) private {
        // Check if all remaining players are all-in or have called
        bool allPlayersActed = true;
        uint256 activeNonAllInCount = 0;
        
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            if (isPlayerIndexInRound[i]) {
                address player = playerIndices[i];
                
                // Count non-all-in players with balance > 0
                if (!isPlayerAllIn[player] && playersBalance[player] > 0) {
                    activeNonAllInCount++;
                    
                    // If player hasn't called the current amount, not all players have acted
                    if (playerAmountInPot[player] < amountToCall) {
                        allPlayersActed = false;
                    }
                }
            }
        }
        
        // Only advance phase if there are no active non-all-in players left to act
        // OR if all non-all-in players have already called
        if (activeNonAllInCount == 0 || (allPlayersActed && activeNonAllInCount > 0)) {
            // first player to act in a round is the SB, or the next player still in play
            uint256 nextFirstPlayer = _findSmallBlind(playerIndexWithBigBlind);
            if (!isPlayerIndexInRound[nextFirstPlayer]) {
                nextFirstPlayer = _findNextBettorIndex(nextFirstPlayer);
            }

            highestBettorIndex = nextFirstPlayer;
            currentBettorIndex = nextFirstPlayer;

            _setCurrentPhase(GamePhases(uint256(currentPhase) + 1));
        } else {
            // If there are still active players to act, update currentBettorIndex to next player
            currentBettorIndex = _nextBettorIndex;
        }
    }

    /* ---------------------------- Private Functions --------------------------- */

    function _setCurrentPhase(GamePhases _newPhase) private {
        GamePhases _previousPhase = currentPhase;
        if (_newPhase == GamePhases.WaitingForPlayers) {
            _resetGameState();
            ++currentRoundId;
        } else if (_newPhase == GamePhases.WaitingForDealer) {
            uint256 _playersLeftInRoundCount = 0;
            for (uint256 i = 0; i < MAX_PLAYERS; i++) {
                address _playerAddress = playerIndices[i];
                if (_playerAddress != address(0) && playersBalance[_playerAddress] > 0) {
                    isPlayerIndexInRound[i] = true;
                    ++_playersLeftInRoundCount;
                }
            }

            playersLeftInRoundCount = _playersLeftInRoundCount;
            require(_playersLeftInRoundCount > 1, NotEnoughPlayers());

            // assign blinds and make players pay them
            // TODO handle cases where players don't have enough tokens to pay the blinds
            (uint256 _SBIndex, uint256 _BBIndex) = _assignNextBlinds();
            address _bb = playerIndices[_BBIndex];
            currentPot += BIG_BLIND_PRICE + (SMALL_BLIND_PRICE);
            playerAmountInPot[_bb] = BIG_BLIND_PRICE;
            playersBalance[_bb] -= BIG_BLIND_PRICE;

            address _sb = playerIndices[_SBIndex];
            if (_sb != address(0)) {
                playerAmountInPot[_sb] = SMALL_BLIND_PRICE;
                playersBalance[_sb] -= SMALL_BLIND_PRICE;
            }

            highestBettorIndex = _BBIndex;
            currentBettorIndex = _findNextBettorIndex(_BBIndex);
            amountToCall = BIG_BLIND_PRICE;
        }

        currentPhase = _newPhase;

        emit PhaseChanged(_newPhase, _previousPhase);
    }

    function _advancePhaseIfNeeded(uint256 _nextBettorIndex) private {
        uint256 _playerIndexWithBigBlind = playerIndexWithBigBlind;
        uint256 _highestBettorIndex = highestBettorIndex;

        // The big blind is allowed to act even if a player calls during the Pre-Flop phase
        if (
            currentPhase == GamePhases.PreFlop && _nextBettorIndex == _highestBettorIndex
                && _nextBettorIndex == _playerIndexWithBigBlind
                && playerAmountInPot[playerIndices[_playerIndexWithBigBlind]] == BIG_BLIND_PRICE
        ) {
            // in that particular case set the `highestBettorIndex` to the next player because the phase needs to advance once it's its turn
            highestBettorIndex = _findNextBettorIndex(_playerIndexWithBigBlind);
            return;
        }

        if (_nextBettorIndex != _highestBettorIndex) {
            return;
        }

        // if the next player to bet is the highest bettor, all the players either folded or called.
        // which means the current phase ended, and the next phase can begin.

        // first player to act in a round is the SB, or the next player still in play
        uint256 nextFirstPlayer = _findSmallBlind(playerIndexWithBigBlind);
        if (!isPlayerIndexInRound[nextFirstPlayer]) {
            nextFirstPlayer = _findNextBettorIndex(nextFirstPlayer);
        }

        highestBettorIndex = nextFirstPlayer;
        currentBettorIndex = nextFirstPlayer;

        _setCurrentPhase(GamePhases(uint256(currentPhase) + 1));
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
            _setCurrentPhase(GamePhases.WaitingForPlayers);
        } else {
            currentBettorIndex = _findNextBettorIndex(playerIndex);
        }
    }

    function _assignNextBlinds() private returns (uint256 SBIndex_, uint256 BBIndex_) {
        uint256 _currentBB = playerIndexWithBigBlind;
        SBIndex_ = _currentBB;
        BBIndex_ = _currentBB + 1;

        while (!isPlayerIndexInRound[BBIndex_]) {
            if (BBIndex_ >= MAX_PLAYERS) {
                BBIndex_ = 0;
            } else {
                ++BBIndex_;
            }
        }

        playerIndexWithBigBlind = BBIndex_;
        return (SBIndex_, BBIndex_);
    }

    function _findNextBettorIndex(uint256 _currentBettorIndex) private view returns (uint256 nextPlayerIndex_) {
        nextPlayerIndex_ = _currentBettorIndex + 1;
        while (
            (!isPlayerIndexInRound[nextPlayerIndex_] 
             || playersBalance[playerIndices[nextPlayerIndex_]] == 0
             || isPlayerAllIn[playerIndices[nextPlayerIndex_]])
                && nextPlayerIndex_ != _currentBettorIndex
        ) {
            if (nextPlayerIndex_ >= MAX_PLAYERS) {
                nextPlayerIndex_ = 0;
            } else {
                ++nextPlayerIndex_;
            }
        }
    }

    function _findSmallBlind(uint256 _bigBlindIndex) private view returns (uint256 smallBlindIndex_) {
        if (_bigBlindIndex == 0) {
            smallBlindIndex_ = MAX_PLAYERS - 1;
        } else {
            smallBlindIndex_ = _bigBlindIndex - 1;
        }

        while (playerAmountInPot[playerIndices[smallBlindIndex_]] == 0 && smallBlindIndex_ != _bigBlindIndex) {
            if (smallBlindIndex_ == 0) {
                smallBlindIndex_ = MAX_PLAYERS - 1;
            } else {
                --smallBlindIndex_;
            }
        }
    }

    function _resetGameState() private {
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address _player = playerIndices[i];
            playerAmountInPot[_player] = 0;
            isPlayerIndexInRound[i] = false;
            isPlayerAllIn[_player] = false;
        }

        playersLeftInRoundCount = 0;
        amountToCall = 0;
        currentPot = 0;
    }

    function _calculateSidePots() private view returns (SidePot[] memory sidePots) {
        // Get all different bet amounts, sorted ascending
        uint256[] memory betAmounts = new uint256[](MAX_PLAYERS);
        uint256 uniqueBetsCount = 0;
        
        for (uint256 i = 0; i < MAX_PLAYERS; i++) {
            address player = playerIndices[i];
            if (player != address(0) && isPlayerIndexInRound[i]) {
                uint256 playerBet = playerAmountInPot[player];
                
                // Only include players who actually contributed money
                if (playerBet > 0) {
                    // Check if this bet amount is already recorded
                    bool found = false;
                    for (uint256 j = 0; j < uniqueBetsCount; j++) {
                        if (betAmounts[j] == playerBet) {
                            found = true;
                            break;
                        }
                    }
                    
                    if (!found) {
                        // Insert in sorted order
                        uint256 insertIndex = uniqueBetsCount;
                        for (uint256 j = 0; j < uniqueBetsCount; j++) {
                            if (playerBet < betAmounts[j]) {
                                insertIndex = j;
                                break;
                            }
                        }
                        
                        // Shift elements to make room
                        for (uint256 j = uniqueBetsCount; j > insertIndex; j--) {
                            betAmounts[j] = betAmounts[j - 1];
                        }
                        
                        betAmounts[insertIndex] = playerBet;
                        uniqueBetsCount++;
                    }
                }
            }
        }
        
        // Create side pots
        sidePots = new SidePot[](uniqueBetsCount);
        uint256 previousAmount = 0;
        
        for (uint256 level = 0; level < uniqueBetsCount; level++) {
            uint256 currentAmount = betAmounts[level];
            uint256 potIncrement = currentAmount - previousAmount;
            
            // Count eligible players for this level (players who contributed at least currentAmount)
            uint256 eligibleCount = 0;
            for (uint256 i = 0; i < MAX_PLAYERS; i++) {
                address player = playerIndices[i];
                if (player != address(0) && isPlayerIndexInRound[i] && playerAmountInPot[player] >= currentAmount && playerAmountInPot[player] > 0) {
                    eligibleCount++;
                }
            }
            
            // Create eligible players array
            address[] memory eligiblePlayers = new address[](eligibleCount);
            uint256 index = 0;
            for (uint256 i = 0; i < MAX_PLAYERS; i++) {
                address player = playerIndices[i];
                if (player != address(0) && isPlayerIndexInRound[i] && playerAmountInPot[player] >= currentAmount && playerAmountInPot[player] > 0) {
                    eligiblePlayers[index] = player;
                    index++;
                }
            }
            
            sidePots[level] = SidePot({
                amount: potIncrement * eligibleCount,
                eligiblePlayers: eligiblePlayers
            });
            
            previousAmount = currentAmount;
        }
        
        return sidePots;
    }
}
