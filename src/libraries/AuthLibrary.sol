// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
/*
  ______   __                      __
 /      \ /  |                    /  |
/$$$$$$  |$$ |  ______    ______  $$ |____
$$ |__$$ |$$ | /      \  /      \ $$      \
$$    $$ |$$ |/$$$$$$  |/$$$$$$  |$$$$$$$  |
$$$$$$$$ |$$ |$$    $$ |$$ |  $$ |$$ |  $$ |
$$ |  $$ |$$ |$$$$$$$$/ $$ |__$$ |$$ |  $$ |
$$ |  $$ |$$ |$$       |$$    $$/ $$ |  $$ |
$$/   $$/ $$/  $$$$$$$/ $$$$$$$/  $$/   $$/
                        $$ |
                        $$ |
                        $$/
*/

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library AuthLibrary {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /**
     * @notice The flow for the settle deposit.
     */
    bytes4 internal constant SETTLE_DEPOSIT = bytes4(keccak256("SETTLE_DEPOSIT"));
    /**
     * @notice The flow for the settle redeem.
     */
    bytes4 internal constant SETTLE_REDEEM = bytes4(keccak256("SETTLE_REDEEM"));

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice The error thrown when the auth signature is expired.
     */
    error AuthSignatureExpired();
    /**
     * @notice The error thrown when the auth signature is invalid.
     */
    error InvalidAuthSignature();

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice The auth signature.
     * @param authSignature The auth signature.
     * @param expiryBlock The expiry block.
     */
    struct AuthSignature {
        bytes authSignature;
        uint256 expiryBlock;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Verifies the vault deployment auth signature.
     * @param _vaultFactory The vault factory.
     * @param _name The name of the vault.
     * @param _configId The config ID of the vault.
     * @param _authSigner The auth signer.
     * @param _authSignature The auth signature.
     */
    function verifyVaultDeploymentAuthSignature(
        address _vaultFactory,
        string memory _name,
        string memory _configId,
        address _authSigner,
        AuthSignature memory _authSignature
    ) internal view {
        bytes32 _hash = keccak256(
            abi.encode(msg.sender, _vaultFactory, _name, _configId, block.chainid, _authSignature.expiryBlock)
        );
        _verifyAuthSignature(_hash, _authSigner, _authSignature);
    }

    /**
     * @notice Verifies the deposit request auth signature.
     * @param _classId The class ID of the deposit request.
     * @param _authSigner The auth signer.
     * @param _authSignature The auth signature.
     */
    function verifyDepositRequestAuthSignature(uint8 _classId, address _authSigner, AuthSignature memory _authSignature)
        internal
        view
    {
        bytes32 _hash =
            keccak256(abi.encode(msg.sender, address(this), block.chainid, _classId, _authSignature.expiryBlock));
        _verifyAuthSignature(_hash, _authSigner, _authSignature);
    }

    /**
     * @notice Verifies the settlement auth signature.
     * @param _flow The flow of the settlement.
     * @param _classId The class ID of the settlement.
     * @param _toBatchId The batch ID of the settlement.
     * @param _manager The manager of the settlement.
     * @param _newTotalAssets The new total assets of the settlement.
     * @param _authSigner The auth signer.
     * @param _authSignature The auth signature.
     */
    function verifySettlementAuthSignature(
        bytes4 _flow,
        uint8 _classId,
        uint48 _toBatchId,
        address _manager,
        uint256[] calldata _newTotalAssets,
        address _authSigner,
        AuthSignature memory _authSignature
    ) internal view {
        bytes32 _hash = keccak256(
            abi.encode(
                _flow,
                _manager,
                address(this),
                block.chainid,
                _classId,
                _toBatchId,
                _newTotalAssets,
                _authSignature.expiryBlock
            )
        );
        _verifyAuthSignature(_hash, _authSigner, _authSignature);
    }

    /**
     * @notice Verifies the auth signature.
     * @param _hash The hash of the auth signature.
     * @param _authSigner The auth signer.
     * @param _authSignature The auth signature.
     */
    function _verifyAuthSignature(bytes32 _hash, address _authSigner, AuthSignature memory _authSignature)
        internal
        view
    {
        if (_authSignature.expiryBlock < block.number) {
            revert AuthSignatureExpired();
        }
        address _signer = _hash.toEthSignedMessageHash().recover(_authSignature.authSignature);
        if (_signer != _authSigner) {
            revert InvalidAuthSignature();
        }
    }
}
