// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { TestDAI } from "test/mocks/TestDAI.sol";
import { TestWETH } from "test/mocks/TestWETH.sol";
import { TestWBTC } from "test/mocks/TestWBTC.sol";

contract DeployTestTokensScript is Script {
    TestDAI dai;
    TestWETH weth;
    TestWBTC wbtc;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        dai = new TestDAI();
        weth = new TestWETH();
        wbtc = new TestWBTC();
        console.log("==dai addr=%s", address(dai));
        console.log("==weth addr=%s", address(weth));
        console.log("==wbtc addr=%s", address(wbtc));
        vm.stopBroadcast();
    }
}

// source .env && forge script script/00_DeployTestTokens.s.sol:DeployTestTokensScript --rpc-url $SEPOLIA_RPC_URL
// --private-key $DEPLOYER_PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
