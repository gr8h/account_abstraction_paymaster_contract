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

    uint256 internal ownerPrivateKey;
    address internal ownerAddress;

    uint256 internal sponsorPrivateKey;
    address internal sponsorAddress;

    uint256 internal userPrivateKey;
    address internal userAddress;

    function setUp() public {
        entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        sponsor = address(address(1));

        ownerPrivateKey = 0x1010101010101010101010101010101010101010101010101010101010101010;
        ownerAddress = vm.addr(ownerPrivateKey);

        sponsorPrivateKey = 0x2020202010101010101010101010101010101010101010101010101010101010;
        sponsorAddress = vm.addr(sponsorPrivateKey);

        userPrivateKey = 0x3030303010101010101010101010101010101010101010101010101010101010;
        userAddress = vm.addr(userPrivateKey);

        paymaster = new EtherspotPaymaster(IEntryPoint(entryPoint));
    }

    function testChangeSponsor() public {
        paymaster.changeSponsor(payable(sponsorAddress));

        assertEq(paymaster.sponsor(), sponsorAddress);
        assertEq(paymaster.sponsorFunds(), 0);
    }

    function testParsePaymasterAndData() public {
        emit log_named_address("userAddress", userAddress);
        // Arrange
        uint48 validUntil = 1628909167;
        uint48 validAfter = 1628909166;

        // Act
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encode("DummyMessage"))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sponsorPrivateKey, msgHash);
        bytes memory sponsorSignature = abi.encodePacked(r, s, v);

        bytes memory paymasterAndData = abi.encodePacked(
            userAddress,
            abi.encode(validUntil, validAfter),
            sponsorAddress,
            sponsorSignature
        );

        emit log_named_bytes("paymasterAndData", paymasterAndData);

        paymasterAndData = hex"96fbeb2e2e17ea5ca71dddb6180b76567bc8b0e10000000000000000000000000000000000000000000000000000000064beb03b0000000000000000000000000000000000000000000000000000000064beada7ea471b5d1e83acdeb64ff079a207a8c9e2d064c8f630fe9239e3f0679b1ce37fdbef6d1d6bd0e5e397c2ae4c712f35ec67ac086433ccca8375aca7dc5c8b7d99e62feb309db1d4b5a4be5f427400ce6885e911ac1c";

        (
            uint48 validUntilReturned,
            uint48 validAfterReturned,
            address sponsorAddressReturned,
            bytes memory signatureReturned
        ) = paymaster.parsePaymasterAndData(paymasterAndData);

        // Assert
        assertEq(sponsorSignature.length, 65);

        assertEq(validUntilReturned, validUntil);
        assertEq(validAfterReturned, validAfter);
        assertEq(sponsorAddressReturned, sponsorAddress);
        assertEq(signatureReturned, sponsorSignature);
    }
}
