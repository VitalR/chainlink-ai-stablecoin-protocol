// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract DeployVaultScript is Script {
    CollateralVault vault;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Get deployed contract addresses
        address stablecoinAddr = SepoliaConfig.AI_STABLECOIN;
        address controllerAddr = SepoliaConfig.AI_CONTROLLER;

        require(stablecoinAddr != address(0), "Stablecoin address not set");
        require(controllerAddr != address(0), "Controller address not set");

        vm.startBroadcast(deployerPrivateKey);

        vault = new CollateralVault(stablecoinAddr, controllerAddr);

        console.log("==AICollateralVault deployed at=%s", address(vault));
        console.log("==Stablecoin addr=%s", stablecoinAddr);
        console.log("==Controller addr=%s", controllerAddr);

        vm.stopBroadcast();
    }
}

// Usage:
// source .env && forge script script/03_DeployVault.s.sol:DeployVaultScript --rpc-url $SEPOLIA_RPC_URL --broadcast
// --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT --gas-price
// $GAS_PRICE --verify -vvvv
