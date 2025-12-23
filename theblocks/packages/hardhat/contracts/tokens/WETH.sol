// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WETH (Wrapped Ether)
 * @author TheBlocks Team - TriHacker Tournament 2025
 * @notice Wrapped Ether for DEX trading
 */
contract WETH is ERC20 {
    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    
    constructor() ERC20("Wrapped Ether", "WETH") {}
    
    /**
     * @notice Wrap ETH to WETH
     */
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice Unwrap WETH to ETH
     */
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "WETH: insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @notice Receive ETH and wrap automatically
     */
    receive() external payable {
        deposit();
    }
}
