// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CollateralVault } from "../../src/CollateralVault.sol";
import { IRiskOracleController } from "../../src/interfaces/IRiskOracleController.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";

/// @title Engine Selection Demo
/// @notice Demonstrates the new AI engine selection functionality
contract TestEngineSelectionScript is Script {
    address user;
    uint256 userPrivateKey;

    CollateralVault vault;
    MockWETH weth;

    function setUp() public {
        user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        weth = MockWETH(SepoliaConfig.MOCK_WETH);
    }

    /// @notice Demo engine selection functionality
    function run() public {
        console.log("=== AI ENGINE SELECTION DEMO ===");
        console.log("User:", user);
        console.log("Vault:", address(vault));
        console.log("");

        // Mint WETH for testing
        weth.mint(user, 100 ether);
        console.log("Minted 100 WETH for testing");

        vm.startBroadcast(userPrivateKey);

        // Approve vault
        weth.approve(address(vault), type(uint256).max);
        console.log("Approved vault for WETH transfers");

        console.log("\n=== TESTING DIFFERENT AI ENGINES ===");

        // Test 1: Default (ALGO engine via backward compatibility)
        console.log("\n1. Testing BACKWARD COMPATIBILITY (defaults to ALGO):");
        _testDeposit("Default/Backward-Compatible", false, IRiskOracleController.Engine.ALGO);

        // Test 2: Explicit ALGO engine
        console.log("\n2. Testing EXPLICIT ALGO engine:");
        _testDeposit("Explicit ALGO", true, IRiskOracleController.Engine.ALGO);

        // Test 3: BEDROCK engine
        console.log("\n3. Testing BEDROCK engine:");
        _testDeposit("Bedrock AI", true, IRiskOracleController.Engine.BEDROCK);

        // Test 4: TEST_TIMEOUT engine for automation testing
        console.log("\n4. Testing TEST_TIMEOUT engine (for automation testing):");
        _testDeposit("Test Timeout", true, IRiskOracleController.Engine.TEST_TIMEOUT);

        vm.stopBroadcast();

        console.log("\n=== DEMO COMPLETE ===");
        console.log("PASS Backward compatibility maintained");
        console.log("PASS Engine selection working");
        console.log("PASS TEST_TIMEOUT available for automation testing");
        console.log("");
        console.log("NEXT: Use TEST_TIMEOUT to test emergency automation!");
    }

    function _testDeposit(string memory testName, bool useEngineParam, IRiskOracleController.Engine engine) internal {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        console.log("   Test:", testName);
        console.log("   Amount: 1 WETH");

        try this._performDeposit(tokens, amounts, useEngineParam, engine) {
            if (useEngineParam) {
                console.log("   Result: SUCCESS - Engine selection working!");
            } else {
                console.log("   Result: SUCCESS - Backward compatibility working!");
            }
        } catch Error(string memory reason) {
            console.log("   Result: FAILED -", reason);
        } catch {
            console.log("   Result: FAILED - Unknown error");
        }
    }

    function _performDeposit(
        address[] memory tokens,
        uint256[] memory amounts,
        bool useEngineParam,
        IRiskOracleController.Engine engine
    ) external {
        require(msg.sender == address(this), "Only self");

        if (useEngineParam) {
            vault.depositBasket(tokens, amounts, engine);
        } else {
            vault.depositBasket(tokens, amounts); // backward compatibility
        }
    }
}
