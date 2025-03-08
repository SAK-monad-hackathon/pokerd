// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin-contracts-5/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("NAME", "SYMBOL") {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
