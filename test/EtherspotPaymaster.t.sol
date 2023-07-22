// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/paymaster/EtherspotPaymaster.sol";
import "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract EtherspotPaymasterTest is Test {
    EtherspotPaymaster public paymaster;
    address public entryPoint;
    address public sponsor;
    uint256 internal signerPrivateKey;
    address internal signer;

    function setUp() public {
        entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        sponsor = address(address(5));

        signerPrivateKey = 0x1010101010101010101010101010101010101010101010101010101010101010;
        signer = vm.addr(signerPrivateKey);

        paymaster = new EtherspotPaymaster(IEntryPoint(entryPoint));
    }

    function testChangeSponsor() public {
        paymaster.changeSponsor(payable(sponsor));

        assertEq(paymaster.sponsor(), sponsor);
        assertEq(paymaster.sponsorFunds(), 0);
    }

    // function testParse() public {
    //     uint48 validUntil = 1628909167;
    //     uint48 validUntil = 1628909166;
    //     address sponsorAddress = sponsor;

    //     bytes32 hash = ECDSA.toEthSignedMessageHash(
    //         getHash(userOp, validUntil, validAfter)
    //     );
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
    //     bytes memory signature = abi.encodePacked(r, s, v);
    //     assertEq(signature.length, 65);
    // }
}
