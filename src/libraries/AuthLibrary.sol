// SPDX-License-Identifier: MIT
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

    struct AuthSignature {
        bytes authSignature;
        uint256 expiryBlock;
    }

    error AuthSignatureExpired();
    error InvalidAuthSignature();

    bytes4 internal constant SETTLE_DEPOSIT = bytes4(keccak256("SETTLE_DEPOSIT"));
    bytes4 internal constant SETTLE_REDEEM = bytes4(keccak256("SETTLE_REDEEM"));

    function verifyVaultDeploymentAuthSignature(
        address _manager,
        address _vaultFactory,
        string memory _name,
        string memory _configId,
        address _authSigner,
        AuthSignature memory _authSignature
    ) internal view {
        bytes32 _hash =
            keccak256(abi.encode(_manager, _vaultFactory, _name, _configId, block.chainid, _authSignature.expiryBlock));
        _verifyAuthSignature(_hash, _authSigner, _authSignature);
    }

    function verifyDepositRequestAuthSignature(uint8 _classId, address _authSigner, AuthSignature memory _authSignature)
        internal
        view
    {
        bytes32 _hash =
            keccak256(abi.encode(msg.sender, address(this), block.chainid, _classId, _authSignature.expiryBlock));
        _verifyAuthSignature(_hash, _authSigner, _authSignature);
    }

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
