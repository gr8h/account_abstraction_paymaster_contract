// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/paymaster/EtherspotPaymaster.sol";
import "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract EtherspotPaymasterScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        EtherspotPaymaster paymaster = new EtherspotPaymaster(
            IEntryPoint(vm.envAddress("ENTRY_POINT"))
        );

        console.logString("paymaster address:");
        console.logAddress(address(paymaster));

        paymaster.changeSponsor(payable(vm.envAddress("SPONSOR_ADDRESS")));

        console.logString("sponsor address:");
        console.logAddress(address(paymaster.sponsor()));

        vm.stopBroadcast();

        uint256 sponsorPrivateKey = vm.envUint("SPONSOR_PRIVATE_KEY");
        vm.startBroadcast(sponsorPrivateKey);

        paymaster.depositFunds{value: 500000000000000000}();
        console.logString("sponsor funds:");
        console.logUint(paymaster.sponsorFunds());

        vm.stopBroadcast();
    }
}
