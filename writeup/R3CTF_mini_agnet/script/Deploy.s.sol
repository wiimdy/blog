// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-ctf/CTFDeployment.sol";

import "src/Challenge.sol";
import "src/Arena.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(
            0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6
        );

        address challenge = address(new Challenge{value: 500 ether}());

        vm.stopBroadcast();
    }
}
