// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25;

import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
abstract contract ExposedVaultTimelocks is AlephVaultBase {
    function minDepositAmountTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT].delegatecall(
            abi.encodeWithSignature("MIN_DEPOSIT_AMOUNT_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function minUserBalanceTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT].delegatecall(
            abi.encodeWithSignature("MIN_USER_BALANCE_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function maxDepositCapTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT].delegatecall(
            abi.encodeWithSignature("MAX_DEPOSIT_CAP_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function noticePeriodTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM].delegatecall(
            abi.encodeWithSignature("NOTICE_PERIOD_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function lockInPeriodTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM].delegatecall(
            abi.encodeWithSignature("LOCK_IN_PERIOD_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function minRedeemAmountTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM].delegatecall(
            abi.encodeWithSignature("MIN_REDEEM_AMOUNT_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function managementFeeTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.FEE_MANAGER].delegatecall(
            abi.encodeWithSignature("MANAGEMENT_FEE_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function performanceFeeTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.FEE_MANAGER].delegatecall(
            abi.encodeWithSignature("PERFORMANCE_FEE_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function accountantTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage()
        .moduleImplementations[ModulesLibrary.FEE_MANAGER].delegatecall(
            abi.encodeWithSignature("ACCOUNTANT_TIMELOCK()")
        );
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }
}

