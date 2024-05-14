// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MemeCoinDexer} from "../src/MemeCoinDexer.sol";
import {MemeProcessManager} from "../src/MemeProcessManager.sol";
import {MemeCoinMinter} from "../src/MemeCoinMinter.sol";
import {DeployMCD} from "../script/DeployMCD.s.sol";
import {DeployMPM} from "../script/DeployMPM.s.sol";
import {DeployMCM} from "../script/DeployMCM.s.sol";

contract MemeCoinDexerTest is Test {
    DeployMCD mcdDeployer;
    DeployMPM mpmDeployer;
    DeployMCM mcmDeployer;

    MemeCoinDexer mcd;
    MemeProcessManager mpm;
    MemeCoinMinter mcm;

    function setUp() public {
        mcdDeployer = new DeployMCD();
        mpmDeployer = new DeployMPM();
        mcmDeployer = new DeployMCM();
    }

    function test_Increment() public {}

    function testFuzz_SetNumber(uint256 x) public {}
}
