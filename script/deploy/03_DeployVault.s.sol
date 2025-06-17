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
        // Use deployed AIUSD and RiskOracleController
        address aiusdAddr = SepoliaConfig.AI_STABLECOIN;
        address controllerAddr = SepoliaConfig.AI_CONTROLLER;

        require(aiusdAddr != address(0), "AIUSD address not set in config");
        require(controllerAddr != address(0), "Controller address not set in config");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy vault with RiskOracleController
        vault = new CollateralVault(aiusdAddr, controllerAddr);

        console.log("==CollateralVault deployed at=%s", address(vault));
        console.log("==AIUSD addr=%s", aiusdAddr);
        console.log("==RiskOracleController addr=%s", controllerAddr);

        // Add supported tokens with initial prices
        vault.addToken(SepoliaConfig.MOCK_DAI, 1e18, 18, "DAI"); // $1 DAI
        vault.addToken(SepoliaConfig.MOCK_WETH, 3500e18, 18, "WETH"); // $3500 ETH
        vault.addToken(SepoliaConfig.MOCK_WBTC, 95_000e18, 18, "WBTC"); // $95000 BTC

        console.log("==Tokens added: DAI, WETH, WBTC");

        vm.stopBroadcast();

        console.log("\n==NEXT STEPS==");
        console.log("1. Update SepoliaConfig.sol with new vault address:");
        console.log("   AI_VAULT = %s", address(vault));
        console.log("2. Authorize vault in AIUSD contract:");
        console.log(
            "   cast send %s 'addVault(address)' %s --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL",
            aiusdAddr,
            address(vault)
        );
        console.log("3. Update frontend config with new vault address");
        console.log("4. System ready with Chainlink Functions integration!");
    }
}

// Usage:
// source .env && forge script script/deploy/03_DeployVault.s.sol:DeployVaultScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
