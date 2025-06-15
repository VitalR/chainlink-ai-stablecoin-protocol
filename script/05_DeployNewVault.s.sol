// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract DeployNewVaultScript is Script {
    CollateralVault vault;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Use existing AIUSD and new mock controller
        address aiusdAddr = SepoliaConfig.AI_STABLECOIN;
        address mockControllerAddr = 0x067b6c730DBFc6F180A70eae12D45305D12fe58A; // From step 2

        require(aiusdAddr != address(0), "AIUSD address not set in config");
        require(mockControllerAddr != address(0), "Mock controller address not set");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new vault with mock controller
        vault = new CollateralVault(aiusdAddr, mockControllerAddr);

        console.log("==New CollateralVault deployed at=%s", address(vault));
        console.log("==AIUSD addr=%s", aiusdAddr);
        console.log("==Controller addr=%s", mockControllerAddr);

        // Add the same tokens as the old vault
        vault.addToken(SepoliaConfig.MOCK_DAI, 1e18, 18, "DAI");      // $1 DAI
        vault.addToken(SepoliaConfig.MOCK_WETH, 2000e18, 18, "WETH"); // $2000 WETH  
        vault.addToken(SepoliaConfig.MOCK_WBTC, 30000e18, 18, "WBTC"); // $30000 WBTC

        console.log("==Tokens added: DAI, WETH, WBTC");

        vm.stopBroadcast();
        
        console.log("\n==NEXT STEPS==");
        console.log("1. Update SepoliaConfig.sol with new vault address:");
        console.log("   AI_VAULT = %s", address(vault));
        console.log("2. Authorize vault in AIUSD contract:");
        console.log("   cast send %s 'addVault(address)' %s --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL", aiusdAddr, address(vault));
        console.log("3. Update frontend config with new vault address");
        console.log("4. System ready for demo!");
    }
}

// Usage:
// source .env && forge script script/05_DeployNewVault.s.sol:DeployNewVaultScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv 