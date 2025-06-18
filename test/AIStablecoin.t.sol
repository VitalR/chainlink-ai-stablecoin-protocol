// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { AIStablecoin } from "../src/AIStablecoin.sol";

/// @title AIStablecoinTest - Comprehensive unit tests for AIStablecoin (AIUSD)
/// @notice Tests token-specific functionality: authorization, minting, burning, ERC20 extensions
contract AIStablecoinTest is Test {
    AIStablecoin public aiusd;

    // Test accounts
    address public owner = makeAddr("owner");
    address public vault1 = makeAddr("vault1");
    address public vault2 = makeAddr("vault2");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public unauthorizedUser = makeAddr("unauthorized");

    // Test constants
    uint256 public constant MINT_AMOUNT = 1000 * 1e18;
    uint256 public constant BURN_AMOUNT = 500 * 1e18;

    // Events to test
    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        vm.startPrank(owner);
        aiusd = new AIStablecoin();

        // Add authorized vaults
        aiusd.addVault(vault1);
        aiusd.addVault(vault2);

        vm.stopPrank();
    }

    /// @notice Test basic token properties
    function test_tokenProperties() public {
        assertEq(aiusd.name(), "AI USD Stablecoin", "Name should be correct");
        assertEq(aiusd.symbol(), "AIUSD", "Symbol should be correct");
        assertEq(aiusd.decimals(), 18, "Decimals should be 18");
        assertEq(aiusd.totalSupply(), 0, "Initial supply should be 0");
        assertEq(aiusd.owner(), owner, "Owner should be set correctly");
    }

    /// @notice Test vault authorization management
    function test_vaultAuthorization() public {
        vm.startPrank(owner);

        address newVault = makeAddr("newVault");

        // Test adding vault
        vm.expectEmit(true, false, false, false);
        emit VaultAdded(newVault);

        aiusd.addVault(newVault);
        assertTrue(aiusd.authorizedVaults(newVault), "Vault should be authorized");

        // Test removing vault
        vm.expectEmit(true, false, false, false);
        emit VaultRemoved(newVault);

        aiusd.removeVault(newVault);
        assertFalse(aiusd.authorizedVaults(newVault), "Vault should be unauthorized");

        vm.stopPrank();
    }

    /// @notice Test vault authorization access control
    function test_vaultAuthorizationAccessControl() public {
        address newVault = makeAddr("newVault");

        // Test unauthorized user cannot add vault
        vm.startPrank(unauthorizedUser);
        vm.expectRevert();
        aiusd.addVault(newVault);
        vm.stopPrank();

        // Test unauthorized user cannot remove vault
        vm.startPrank(unauthorizedUser);
        vm.expectRevert();
        aiusd.removeVault(vault1);
        vm.stopPrank();

        // Verify vault states unchanged
        assertFalse(aiusd.authorizedVaults(newVault), "New vault should not be authorized");
        assertTrue(aiusd.authorizedVaults(vault1), "Existing vault should remain authorized");
    }

    /// @notice Test vault authorization with zero address
    function test_vaultAuthorizationZeroAddress() public {
        vm.startPrank(owner);

        // Test adding zero address
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAddress.selector, address(0)));
        aiusd.addVault(address(0));

        // Test removing zero address
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAddress.selector, address(0)));
        aiusd.removeVault(address(0));

        vm.stopPrank();
    }

    /// @notice Test minting functionality
    function test_mint() public {
        vm.startPrank(vault1);

        uint256 initialSupply = aiusd.totalSupply();
        uint256 initialBalance = aiusd.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, MINT_AMOUNT);

        bool success = aiusd.mint(user1, MINT_AMOUNT);

        assertTrue(success, "Mint should return true");
        assertEq(aiusd.totalSupply(), initialSupply + MINT_AMOUNT, "Total supply should increase");
        assertEq(aiusd.balanceOf(user1), initialBalance + MINT_AMOUNT, "User balance should increase");

        vm.stopPrank();
    }

    /// @notice Test minting access control
    function test_mintAccessControl() public {
        // Test unauthorized user cannot mint
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(AIStablecoin.UnauthorizedAccount.selector);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // Test user cannot mint directly
        vm.startPrank(user1);
        vm.expectRevert(AIStablecoin.UnauthorizedAccount.selector);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Test minting with invalid parameters
    function test_mintInvalidParameters() public {
        vm.startPrank(vault1);

        // Test minting to zero address
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAddress.selector, address(0)));
        aiusd.mint(address(0), MINT_AMOUNT);

        // Test minting zero amount
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAmount.selector, 0));
        aiusd.mint(user1, 0);

        vm.stopPrank();
    }

    /// @notice Test direct burning functionality
    function test_burn() public {
        // Setup: mint tokens first
        vm.startPrank(vault1);
        aiusd.mint(vault1, MINT_AMOUNT);
        vm.stopPrank();

        // Test burning
        vm.startPrank(vault1);
        uint256 initialSupply = aiusd.totalSupply();
        uint256 initialBalance = aiusd.balanceOf(vault1);

        vm.expectEmit(true, true, false, true);
        emit Transfer(vault1, address(0), BURN_AMOUNT);

        aiusd.burn(BURN_AMOUNT);

        assertEq(aiusd.totalSupply(), initialSupply - BURN_AMOUNT, "Total supply should decrease");
        assertEq(aiusd.balanceOf(vault1), initialBalance - BURN_AMOUNT, "Vault balance should decrease");

        vm.stopPrank();
    }

    /// @notice Test burn access control
    function test_burnAccessControl() public {
        // Setup: mint tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // Test unauthorized user cannot burn
        vm.startPrank(user1);
        vm.expectRevert(AIStablecoin.UnauthorizedAccount.selector);
        aiusd.burn(BURN_AMOUNT);
        vm.stopPrank();

        // Test unauthorized user cannot burn
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(AIStablecoin.UnauthorizedAccount.selector);
        aiusd.burn(BURN_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Test burn with invalid amount
    function test_burnInvalidAmount() public {
        vm.startPrank(vault1);

        // Test burning zero amount
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAmount.selector, 0));
        aiusd.burn(0);

        vm.stopPrank();
    }

    /// @notice Test burnFrom functionality with proper allowance
    function test_burnFrom() public {
        // Setup: mint tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // User approves vault to burn tokens
        vm.startPrank(user1);
        aiusd.approve(vault1, BURN_AMOUNT);
        vm.stopPrank();

        // Vault burns tokens from user
        vm.startPrank(vault1);
        uint256 initialSupply = aiusd.totalSupply();
        uint256 initialUserBalance = aiusd.balanceOf(user1);
        uint256 initialAllowance = aiusd.allowance(user1, vault1);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), BURN_AMOUNT);

        aiusd.burnFrom(user1, BURN_AMOUNT);

        assertEq(aiusd.totalSupply(), initialSupply - BURN_AMOUNT, "Total supply should decrease");
        assertEq(aiusd.balanceOf(user1), initialUserBalance - BURN_AMOUNT, "User balance should decrease");
        assertEq(aiusd.allowance(user1, vault1), initialAllowance - BURN_AMOUNT, "Allowance should decrease");

        vm.stopPrank();
    }

    /// @notice Test burnFrom with infinite allowance
    function test_burnFromInfiniteAllowance() public {
        // Setup: mint tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // User approves vault with infinite allowance
        vm.startPrank(user1);
        aiusd.approve(vault1, type(uint256).max);
        vm.stopPrank();

        // Vault burns tokens from user
        vm.startPrank(vault1);
        uint256 initialAllowance = aiusd.allowance(user1, vault1);

        aiusd.burnFrom(user1, BURN_AMOUNT);

        // Infinite allowance should remain unchanged
        assertEq(aiusd.allowance(user1, vault1), initialAllowance, "Infinite allowance should remain unchanged");

        vm.stopPrank();
    }

    /// @notice Test burnFrom access control
    function test_burnFromAccessControl() public {
        // Setup: mint tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // Test unauthorized user cannot burnFrom
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(AIStablecoin.UnauthorizedAccount.selector);
        aiusd.burnFrom(user1, BURN_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Test burnFrom with insufficient allowance
    function test_burnFromInsufficientAllowance() public {
        // Setup: mint tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // User approves insufficient amount
        vm.startPrank(user1);
        aiusd.approve(vault1, BURN_AMOUNT - 1);
        vm.stopPrank();

        // Vault tries to burn more than approved
        vm.startPrank(vault1);
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAmount.selector, BURN_AMOUNT));
        aiusd.burnFrom(user1, BURN_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Test burnFrom with insufficient balance
    function test_burnFromInsufficientBalance() public {
        // Setup: mint insufficient tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, BURN_AMOUNT - 1);
        vm.stopPrank();

        // User approves sufficient allowance
        vm.startPrank(user1);
        aiusd.approve(vault1, BURN_AMOUNT);
        vm.stopPrank();

        // Vault tries to burn more than user has
        vm.startPrank(vault1);
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAmount.selector, BURN_AMOUNT));
        aiusd.burnFrom(user1, BURN_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Test burnFrom with invalid parameters
    function test_burnFromInvalidParameters() public {
        vm.startPrank(vault1);

        // Test burning zero amount
        vm.expectRevert(abi.encodeWithSelector(AIStablecoin.InvalidAmount.selector, 0));
        aiusd.burnFrom(user1, 0);

        vm.stopPrank();
    }

    /// @notice Test multiple vaults can operate independently
    function test_multipleVaults() public {
        // Vault1 mints to user1
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // Vault2 mints to user2
        vm.startPrank(vault2);
        aiusd.mint(user2, MINT_AMOUNT * 2);
        vm.stopPrank();

        // Verify balances
        assertEq(aiusd.balanceOf(user1), MINT_AMOUNT, "User1 balance should be correct");
        assertEq(aiusd.balanceOf(user2), MINT_AMOUNT * 2, "User2 balance should be correct");
        assertEq(aiusd.totalSupply(), MINT_AMOUNT * 3, "Total supply should be sum of mints");

        // Both vaults can burn their minted tokens
        vm.startPrank(user1);
        aiusd.approve(vault1, BURN_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        aiusd.approve(vault2, BURN_AMOUNT);
        vm.stopPrank();

        vm.startPrank(vault1);
        aiusd.burnFrom(user1, BURN_AMOUNT);
        vm.stopPrank();

        vm.startPrank(vault2);
        aiusd.burnFrom(user2, BURN_AMOUNT);
        vm.stopPrank();

        // Verify final balances
        assertEq(aiusd.balanceOf(user1), MINT_AMOUNT - BURN_AMOUNT, "User1 final balance should be correct");
        assertEq(aiusd.balanceOf(user2), MINT_AMOUNT * 2 - BURN_AMOUNT, "User2 final balance should be correct");
    }

    /// @notice Test removing active vault
    function test_removeActiveVault() public {
        // Vault mints tokens
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // Owner removes vault
        vm.startPrank(owner);
        aiusd.removeVault(vault1);
        vm.stopPrank();

        // Removed vault cannot mint anymore
        vm.startPrank(vault1);
        vm.expectRevert(AIStablecoin.UnauthorizedAccount.selector);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // But existing tokens remain functional
        assertEq(aiusd.balanceOf(user1), MINT_AMOUNT, "Existing tokens should remain");

        // User can still transfer tokens normally
        vm.startPrank(user1);
        aiusd.transfer(user2, MINT_AMOUNT / 2);
        vm.stopPrank();

        assertEq(aiusd.balanceOf(user1), MINT_AMOUNT / 2, "User1 balance after transfer");
        assertEq(aiusd.balanceOf(user2), MINT_AMOUNT / 2, "User2 balance after transfer");
    }

    /// @notice Test standard ERC20 functionality works normally
    function test_standardERC20Functionality() public {
        // Mint tokens to user
        vm.startPrank(vault1);
        aiusd.mint(user1, MINT_AMOUNT);
        vm.stopPrank();

        // Test transfer
        vm.startPrank(user1);
        bool success = aiusd.transfer(user2, BURN_AMOUNT);
        assertTrue(success, "Transfer should succeed");
        assertEq(aiusd.balanceOf(user1), MINT_AMOUNT - BURN_AMOUNT, "User1 balance after transfer");
        assertEq(aiusd.balanceOf(user2), BURN_AMOUNT, "User2 balance after transfer");

        // Test approve and transferFrom
        aiusd.approve(user2, BURN_AMOUNT / 2);
        vm.stopPrank();

        vm.startPrank(user2);
        bool transferFromSuccess = aiusd.transferFrom(user1, user2, BURN_AMOUNT / 2);
        assertTrue(transferFromSuccess, "TransferFrom should succeed");
        vm.stopPrank();

        assertEq(aiusd.balanceOf(user1), MINT_AMOUNT - BURN_AMOUNT - BURN_AMOUNT / 2, "User1 final balance");
        assertEq(aiusd.balanceOf(user2), BURN_AMOUNT + BURN_AMOUNT / 2, "User2 final balance");
    }
}
