// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockPYUSD
 * @notice Mock PayPal USD Stablecoin for demo purposes
 * @dev Mimics PYUSD behavior for hackathon demonstration
 */
contract MockPYUSD is ERC20, Ownable {
    uint8 private _decimals = 6; // PYUSD uses 6 decimals like USDC
    
    constructor() ERC20("PayPal USD", "PYUSD") Ownable(msg.sender) {
        // Mint 1 billion tokens to deployer for demo
        _mint(msg.sender, 1_000_000_000 * 10**_decimals);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @notice Mint tokens (for demo faucet)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @notice Faucet - anyone can get 10,000 PYUSD for testing
     */
    function faucet() external {
        _mint(msg.sender, 10_000 * 10**_decimals);
    }
    
    /**
     * @notice Faucet with custom amount (max 1M)
     */
    function faucetAmount(uint256 amount) external {
        require(amount <= 1_000_000 * 10**_decimals, "Max 1M per faucet");
        _mint(msg.sender, amount);
    }
}

/**
 * @title MockUSDC
 * @notice Mock USDC for demo purposes
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private _decimals = 6;
    
    constructor() ERC20("USD Coin", "USDC") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000_000 * 10**_decimals);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function faucet() external {
        _mint(msg.sender, 10_000 * 10**_decimals);
    }
    
    function faucetAmount(uint256 amount) external {
        require(amount <= 1_000_000 * 10**_decimals, "Max 1M per faucet");
        _mint(msg.sender, amount);
    }
}

/**
 * @title MockUSDT
 * @notice Mock USDT for demo purposes
 */
contract MockUSDT is ERC20, Ownable {
    uint8 private _decimals = 6;
    
    constructor() ERC20("Tether USD", "USDT") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000_000 * 10**_decimals);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function faucet() external {
        _mint(msg.sender, 10_000 * 10**_decimals);
    }
    
    function faucetAmount(uint256 amount) external {
        require(amount <= 1_000_000 * 10**_decimals, "Max 1M per faucet");
        _mint(msg.sender, amount);
    }
}
