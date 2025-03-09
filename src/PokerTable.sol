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
    mapping(uint256 => address) public playerIndexes;
    mapping(address => uint256) public reversePlayerIndexes;
    mapping(address => uint256) public playersBalance;
    uint256 public playerCount;
    uint256 public playerIndexWithBigBlind;
    GamePhases public currentPhase;
    uint256 public currentPot;

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
        require(playerIndexes[_indexOnTable] == address(0), OccupiedSeat());
        require(_buyIn >= MIN_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());
        require(_buyIn <= MAX_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());

        players[msg.sender] = true;
        playerIndexes[_indexOnTable] = msg.sender;
        reversePlayerIndexes[msg.sender] = _indexOnTable;
        ++playerCount;
        playersBalance[msg.sender] = _buyIn;

        currency.safeTransferFrom(msg.sender, address(this), _buyIn);
    }

    function leaveTable() external {
        require(players[msg.sender], NotAPlayer());

        players[msg.sender] = false;
        uint256 playerIndex = reversePlayerIndexes[msg.sender];
        reversePlayerIndexes[msg.sender] = 0;
        playerIndexes[playerIndex] = address(0);
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
        } else if (_newPhase == GamePhases.WaitingForDealer) {
            require(playerCount > 1, NotEnoughPlayers());
        }

        _setCurrentPhase(_newPhase);
    }

    /* ---------------------------- Private Functions --------------------------- */
    function _setCurrentPhase(GamePhases _newPhase) private {
        currentPhase = _newPhase;

        if (_newPhase == GamePhases.PreFlop) {
            // assign blinds and make players pay them
            (uint256 _SBIndex, uint256 _BBIndex) = _assignNextBlinds();
            currentPot += bigBlindPrice;
            playersBalance[playerIndexes[_BBIndex]] -= bigBlindPrice;
            playersBalance[playerIndexes[_SBIndex]] -= bigBlindPrice / 2;
        } else if (_newPhase == GamePhases.WaitingForPlayers || _newPhase == GamePhases.WaitingForDealer) {
            currentPot = 0;
        }
    }

    function _assignNextBlinds() private returns (uint256 SBIndex_, uint256 BBIndex_) {
        uint256 _currentBB = playerIndexWithBigBlind;
        SBIndex_ = _currentBB;
        BBIndex_ = _currentBB + 1;

        while (playerIndexes[BBIndex_] == address(0)) {
            if (BBIndex_ >= MAX_PLAYERS) {
                BBIndex_ = 0;
            } else {
                ++BBIndex_;
            }
        }

        playerIndexWithBigBlind = BBIndex_;
        return (SBIndex_, BBIndex_);
    }
}
