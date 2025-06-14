// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIController } from "src/AIController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract DeployAIControllerScript is Script {
    AIController controller;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Configuration for controller
        address oracleAddr = SepoliaConfig.ORA_ORACLE;
        uint256 modelId = 11; // Default ORA model
        uint256 oracleFee = 0.01 ether; // Default oracle fee

        require(oracleAddr != address(0), "Oracle address not set");

        vm.startBroadcast(deployerPrivateKey);

        controller = new AIController(oracleAddr, modelId, oracleFee);

        console.log("==AIController deployed at=%s", address(controller));
        console.log("==Oracle addr=%s", oracleAddr);
        console.log("==Model ID=%s", modelId);
        console.log("==Oracle fee=%s", oracleFee);

        vm.stopBroadcast();
    }
}

// Usage:
// source .env && forge script script/02_DeployAIController.s.sol:DeployAIControllerScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv
