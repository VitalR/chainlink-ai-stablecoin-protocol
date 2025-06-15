// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/MockAIOracleDemo.sol";
import "../src/AIController.sol";
import "../src/CollateralVault.sol";

contract DeployMockOracleDemo is Script {
    // Existing deployed addresses
    address constant EXISTING_VAULT = 0x0d8a34dCD87b50291c4F7b0706Bfde71Abd1aFf2;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Mock Oracle first
        MockAIOracleDemo mockOracle = new MockAIOracleDemo();
        console.log("MockAIOracleDemo deployed at:", address(mockOracle));
        
        // Deploy new AIController with mock oracle
        uint256 modelId = 1; // Mock model ID
        uint256 oracleFee = 0.001 ether; // Much lower fee for demo
        
        AIController newController = new AIController(
            address(mockOracle),
            modelId,
            oracleFee
        );
        console.log("New AIController deployed at:", address(newController));
        
        // Authorize the vault in the new controller
        newController.setAuthorizedCaller(EXISTING_VAULT, true);
        console.log("Vault authorized in new controller");
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Mock Oracle:", address(mockOracle));
        console.log("New AI Controller:", address(newController));
        console.log("Vault (To Update):", EXISTING_VAULT);
        console.log("Oracle Fee: 0.001 ether");
        
        console.log("\n=== MANUAL STEP REQUIRED ===");
        console.log("The vault owner needs to update the controller:");
        console.log("cast send %s", EXISTING_VAULT);
        console.log("'updateController(address)' %s", address(newController));
        console.log("--private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL");
        
        console.log("\n=== AFTER MANUAL UPDATE ===");
        console.log("- No frontend changes needed!");
        console.log("- All existing addresses work");
        console.log("- Frontend will work immediately");
        
        console.log("\n=== DEMO FLOW ===");
        console.log("1. Run the manual cast command above");
        console.log("2. Frontend works with existing addresses");
        console.log("3. User deposits collateral via frontend");
        console.log("4. Wait 10 seconds for 'AI processing'");
        console.log("5. Call processRequest() to complete:");
        console.log("   cast send %s", address(mockOracle));
        console.log("   'processRequest(uint256)' 1");
        console.log("   --private-key=$PRIVATE_KEY --rpc-url=$SEPOLIA_RPC_URL");
    }
} 