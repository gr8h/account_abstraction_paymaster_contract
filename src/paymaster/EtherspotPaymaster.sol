// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable reason-string */

import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./BasePaymaster.sol";

/**
 * A sample paymaster that uses external service to decide whether to pay for the UserOp.
 * The paymaster trusts an external signer to sign the transaction.
 * The calling user must pass the UserOp to that external signer first, which performs
 * whatever off-chain verification before signing the UserOp.
 * Note that this signature is NOT a replacement for wallet signature:
 * - the paymaster signs to agree to PAY for GAS.
 * - the wallet signs to prove identity and account ownership.
 */
contract EtherspotPaymaster is BasePaymaster, ReentrancyGuard {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    uint256 private constant VALID_TIMESTAMP_OFFSET = 20;
    uint256 private constant SPONSOR_OFFSET = 84;
    uint256 private constant SIGNATURE_OFFSET = 104;
    // calculated cost of the postOp
    uint256 private constant COST_OF_POST = 40000;

    address payable public sponsor;
    uint256 public sponsorFunds;

    event SponsorSuccessful(address paymaster, address sender);
    event SponsorUnsuccessful(address paymaster, address sender);

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {}

    function changeSponsor(address payable _sponsor) external onlyOwner {
        sponsorFunds = 0;
        sponsor = _sponsor;
    }

    function depositFunds() external payable nonReentrant {
        require(
            msg.sender == sponsor,
            "EtherspotPaymaster:: can only withdraw own funds"
        );
        require(msg.value > 0, "EtherspotPaymaster:: amount must be > 0");

        entryPoint.depositTo{value: msg.value}(address(this));
        _creditSponsor(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _amount) external nonReentrant {
        require(
            msg.sender == sponsor,
            "EtherspotPaymaster:: can only withdraw own funds"
        );
        require(
            sponsorFunds >= _amount,
            "EtherspotPaymaster:: not enough deposited funds"
        );
        _debitSponsor(sponsor, _amount);
        entryPoint.withdrawTo(sponsor, _amount);
    }

    function _debitSponsor(address _sponsor, uint256 _amount) internal {
        require(
            _sponsor == sponsor,
            "EtherspotPaymaster:: can only withdraw own funds"
        );
        sponsorFunds -= _amount;
    }

    function _creditSponsor(address _sponsor, uint256 _amount) internal {
        require(
            _sponsor == sponsor,
            "EtherspotPaymaster:: can only withdraw own funds"
        );
        sponsorFunds += _amount;
    }

    function _pack(
        UserOperation calldata userOp
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    userOp.getSender(),
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.callGasLimit,
                    userOp.verificationGasLimit,
                    userOp.preVerificationGas,
                    userOp.maxFeePerGas,
                    userOp.maxPriorityFeePerGas
                )
            );
    }

    /**
     * return the hash we're going to sign off-chain (and validate on-chain)
     * this method is called by the off-chain service, to sign the request.
     * it is called on-chain from the validatePaymasterUserOp, to validate the signature.
     * note that this signature covers all fields of the UserOperation, except the "paymasterAndData",
     * which will carry the signature itself.
     */
    function getHash(
        UserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) public view returns (bytes32) {
        //can't use userOp.hash(), since it contains also the paymasterAndData itself.

        return
            keccak256(
                abi.encode(
                    _pack(userOp),
                    block.chainid,
                    address(this),
                    validUntil,
                    validAfter
                )
            );
    }

    /**
     * verify our external signer signed this request.
     * the "paymasterAndData" is expected to be the paymaster and a signature over the entire request params
     * paymasterAndData[:20] : address(this)
     * paymasterAndData[20:84] : abi.encode(validUntil, validAfter)
     * paymasterAndData[84:104] : sponsorAddress
     * paymasterAndData[104:] : signature
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 requiredPreFund
    ) internal override returns (bytes memory context, uint256 validationData) {
        (requiredPreFund);

        (
            uint48 validUntil,
            uint48 validAfter,
            address sponsorAddress,
            bytes calldata signature
        ) = parsePaymasterAndData(userOp.paymasterAndData);
        // ECDSA library supports both 64 and 65-byte long signatures.
        // we only "require" it here so that the revert reason on invalid signature will be of "EtherspotPaymaster", and not "ECDSA"
        require(
            signature.length == 64 || signature.length == 65,
            "EtherspotPaymaster:: invalid signature length in paymasterAndData"
        );
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            getHash(userOp, validUntil, validAfter)
        );
        address sig = userOp.getSender();

        // check for valid paymaster
        address sponsorSig = ECDSA.recover(hash, signature);
        require(
            sponsorSig == sponsorAddress,
            "EtherspotPaymaster:: Invalid sponsor address"
        );

        // check sponsor has enough funds deposited to pay for gas
        require(
            sponsorFunds >= requiredPreFund,
            "EtherspotPaymaster:: Sponsor paymaster funds too low"
        );

        uint256 costOfPost = userOp.maxFeePerGas * COST_OF_POST;

        // debit requiredPreFund amount
        _debitSponsor(sponsorSig, requiredPreFund);

        // no need for other on-chain validation: entire UserOp should have been checked
        // by the external service prior to signing it.
        return (
            abi.encode(sponsorSig, sig, requiredPreFund, costOfPost),
            _packValidationData(false, validUntil, validAfter)
        );
    }

    function parsePaymasterAndData(
        bytes calldata paymasterAndData
    )
        public
        pure
        returns (
            uint48 validUntil,
            uint48 validAfter,
            address sponsorAddress,
            bytes calldata signature
        )
    {
        (validUntil, validAfter) = abi.decode(
            paymasterAndData[VALID_TIMESTAMP_OFFSET:SPONSOR_OFFSET],
            (uint48, uint48)
        );
        sponsorAddress = _extractAddress(paymasterAndData, SPONSOR_OFFSET);
        signature = paymasterAndData[SIGNATURE_OFFSET:];
    }

    function _extractAddress(
        bytes memory data,
        uint256 offset
    ) internal pure returns (address sponsorAddress) {
        require(
            data.length >= offset + 20,
            "EtherspotPaymaster: data length is less than required"
        );

        assembly {
            sponsorAddress := mload(add(data, add(offset, 20)))
        }
    }

    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        (
            address paymaster,
            address sender,
            uint256 prefundedAmount,
            uint256 costOfPost
        ) = abi.decode(context, (address, address, uint256, uint256));
        if (mode == PostOpMode.postOpReverted) {
            _creditSponsor(paymaster, prefundedAmount);
            emit SponsorUnsuccessful(paymaster, sender);
        } else {
            _creditSponsor(
                paymaster,
                prefundedAmount - (actualGasCost + costOfPost)
            );
            emit SponsorSuccessful(paymaster, sender);
        }
    }
}
