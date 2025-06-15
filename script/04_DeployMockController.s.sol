// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIController } from "src/AIController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract DeployMockControllerScript is Script {
    AIController controller;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Configuration for mock oracle controller
        address mockOracleAddr = SepoliaConfig.MOCK_ORACLE;
        uint256 modelId = 1; // Mock model ID
        uint256 oracleFee = 0.001 ether; // Lower fee for demo

        require(mockOracleAddr != address(0), "Mock oracle address not set in config");

        vm.startBroadcast(deployerPrivateKey);

        controller = new AIController(mockOracleAddr, modelId, oracleFee);

        console.log("==AIController (Mock) deployed at=%s", address(controller));
        console.log("==Mock Oracle addr=%s", mockOracleAddr);
        console.log("==Model ID=%s", modelId);
        console.log("==Oracle fee=%s", oracleFee);
        
        // Authorize the existing vault
        address vaultAddr = SepoliaConfig.AI_VAULT;
        controller.setAuthorizedCaller(vaultAddr, true);
        console.log("==Vault authorized: %s", vaultAddr);

        vm.stopBroadcast();
        
        console.log("\n==NEXT STEPS==");
        console.log("1. Update vault controller:");
        console.log("   cast send %s 'updateController(address)' %s --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL", vaultAddr, address(controller));
        console.log("2. System will be ready for demo!");
    }
}

// Usage:
// 1. First deploy mock oracle with script 03
// 2. Add MOCK_ORACLE_ADDR=0x... to .env
// 3. Run: source .env && forge script script/04_DeployMockController.s.sol:DeployMockControllerScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv 