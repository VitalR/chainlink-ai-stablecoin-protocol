// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";

contract DeployAIControllerScript is Script {
    AIControllerCallback controller;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    // ORA Oracle configuration for Sepolia (official address from ORA docs)
    address constant ORA_ORACLE_SEPOLIA = 0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0;
    uint256 constant MODEL_ID = 11; // Llama3 8B Instruct
    uint64 constant CALLBACK_GAS_LIMIT = 500_000;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        controller = new AIControllerCallback(ORA_ORACLE_SEPOLIA, MODEL_ID, CALLBACK_GAS_LIMIT);

        console.log("==AIControllerCallback addr=%s", address(controller));
        console.log("==Oracle addr=%s", ORA_ORACLE_SEPOLIA);
        console.log("==Model ID=%s", MODEL_ID);

        vm.stopBroadcast();
    }
}

// source .env && forge script script/02_DeployAIController.s.sol:DeployAIControllerScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv
