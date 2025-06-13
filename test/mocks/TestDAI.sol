// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

contract TestDAI is ERC20 {
    constructor() ERC20("TestDAI", "TestDAI", 18) { }

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address from, uint256 value) public returns (bool) {
        _burn(from, value);
        return true;
    }
}
