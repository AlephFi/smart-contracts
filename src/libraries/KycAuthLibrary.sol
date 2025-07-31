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
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @dev This library verifies the KYC authentication signature.
 */
library KycAuthLibrary {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct KycAuthSignature {
        bytes authSignature;
        uint256 expiryBlock;
    }

    error KycAuthSignatureExpired();
    error InvalidKycAuthSignature();

    function verifyKycAuthSignature(AlephVaultStorageData storage _sd, KycAuthSignature memory _kycAuthSignature) internal view {
        if (_kycAuthSignature.expiryBlock < block.number) {
            revert KycAuthSignatureExpired();
        }
        bytes32 _hash = keccak256(abi.encode(msg.sender, address(this), block.chainid, _kycAuthSignature.expiryBlock));
        address _signer = _hash.toEthSignedMessageHash().recover(_kycAuthSignature.authSignature);
        if (_signer != _sd.guardian) {
            revert InvalidKycAuthSignature();
        }
    }
}