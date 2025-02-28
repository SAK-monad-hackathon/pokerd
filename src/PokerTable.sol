// SPDX-License-Identifier: BUSL
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5/token/ERC20/IERC20.sol";

contract PokerTable {
    IERC20 public immutable currency;

    constructor(IERC20 _currency) {
        currency = _currency;
    }
}
