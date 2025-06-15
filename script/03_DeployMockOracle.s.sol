// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { MockAIOracleDemo } from "src/MockAIOracleDemo.sol";

contract DeployMockOracleScript is Script {
    MockAIOracleDemo mockOracle;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        mockOracle = new MockAIOracleDemo();

        console.log("==MockAIOracleDemo deployed at=%s", address(mockOracle));
        console.log("==Processing delay=10 seconds");
        console.log("==Fee=0.001 ether");

        vm.stopBroadcast();
    }
}

// Usage:
// source .env && forge script script/03_DeployMockOracle.s.sol:DeployMockOracleScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT  
// --gas-price $GAS_PRICE --verify -vvvv 