// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";

contract DeployStablecoinScript is Script {
    AIStablecoin stablecoin;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        stablecoin = new AIStablecoin();
        console.log("==stablecoin addr=%s", address(stablecoin));
        vm.stopBroadcast();
    }
}

// source .env && forge script script/01_DeployStablecoin.s.sol:DeployStablecoinScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv
