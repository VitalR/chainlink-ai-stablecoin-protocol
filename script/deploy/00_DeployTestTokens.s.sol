// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { MockDAI } from "test/mocks/MockDAI.sol";
import { MockWETH } from "test/mocks/MockWETH.sol";
import { MockWBTC } from "test/mocks/MockWBTC.sol";
import { MockUSDC } from "test/mocks/MockUSDC.sol";

contract DeployTestTokensScript is Script {
    MockDAI dai;
    MockWETH weth;
    MockWBTC wbtc;
    MockUSDC usdc;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        dai = new MockDAI();
        weth = new MockWETH();
        wbtc = new MockWBTC();
        usdc = new MockUSDC();
        console.log("==dai addr=%s", address(dai));
        console.log("==weth addr=%s", address(weth));
        console.log("==wbtc addr=%s", address(wbtc));
        console.log("==usdc addr=%s", address(usdc));
        vm.stopBroadcast();
    }
}

// source .env && forge script script/00_DeployTestTokens.s.sol:DeployTestTokensScript --rpc-url $SEPOLIA_RPC_URL
// --private-key $DEPLOYER_PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
