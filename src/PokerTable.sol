// SPDX-License-Identifier: BUSL
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

import {IPokerTable} from "./interfaces/IPokerTable.sol";

contract PokerTable is IPokerTable {
    /* -------------------------------- Constants ------------------------------- */

    uint8 public constant MAX_PLAYERS = 5;

    /// @notice Minimum buy-in (in Big Blings)
    uint8 public constant MIN_BUY_IN_BB = 40;

    /// @notice Maximum buy-in (in Big Blings)
    uint8 public constant MAX_BUY_IN_BB = 100;

    /* ------------------------------- Immutables ------------------------------- */

    IERC20 public immutable currency;
    uint256 public immutable bigBlindPrice;
    uint256 public immutable smallBlindPrice;

    /* ----------------------------- State Variables ---------------------------- */

    mapping(address => bool) public players;
    uint256 public playerCount;
    GamePhases public currentPhase;

    constructor(IERC20 _currency, uint256 _bigBlindPrice) {
        currency = _currency;

        require(_bigBlindPrice > 1, BigBlindPriceIsTooLow(_bigBlindPrice));
        bigBlindPrice = _bigBlindPrice;
        // rounding down is expected here
        smallBlindPrice = _bigBlindPrice / 2;
    }

    function joinTable(uint256 _buyIn) external {
        uint256 _bigBlindPrice = bigBlindPrice;
        require(playerCount < MAX_PLAYERS, TableIsFull());
        require(_buyIn >= MIN_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());
        require(_buyIn <= MAX_BUY_IN_BB * _bigBlindPrice, InvalidBuyIn());

        players[msg.sender] = true;
        ++playerCount;
    }

    function leaveTable() external {
        require(players[msg.sender], NotAPlayer());

        players[msg.sender] = false;
        --playerCount;
    }

    // TODO should only be callable by dealer
    function setCurrentPhase(GamePhases _newPhase) external {
        GamePhases _currentPhase = currentPhase;
        if (_newPhase != GamePhases.PreFlop && _newPhase != GamePhases.WaitingForPlayers) {
            require(uint256(_newPhase) == uint256(_currentPhase) + 1, SkippingPhasesIsNotAllowed());
        } else if (_newPhase == GamePhases.PreFlop) {
            require(playerCount > 1, NotEnoughPlayers());
        }

        _setCurrentPhase(_newPhase);
    }

    /* ---------------------------- Private Functions --------------------------- */
    function _setCurrentPhase(GamePhases _newPhase) private {
        currentPhase = _newPhase;
    }
}
