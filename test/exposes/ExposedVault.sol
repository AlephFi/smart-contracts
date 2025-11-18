// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25;
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

import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {ExposedVaultSetters} from "@aleph-test/exposes/ExposedVaultSetters.sol";
import {ExposedVaultTimelocks} from "@aleph-test/exposes/ExposedVaultTimelocks.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract ExposedVault is AlephVault, ExposedVaultSetters, ExposedVaultTimelocks {
    uint256 public constant PRICE_DENOMINATOR = 1e6;
    uint256 public constant TOTAL_SHARE_UNITS = 1e18;

    constructor(uint48 _batchDuration) AlephVault(_batchDuration) {}

    function accumulateFees(uint8, uint32, uint48, uint48, uint256, uint256) external returns (uint256) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    function depositSettleId() external view returns (uint48) {
        return _getStorage().shareClasses[1].depositSettleId;
    }

    function redeemSettleId() external view returns (uint48) {
        return _getStorage().shareClasses[1].redeemSettleId;
    }

    function lastFeePaidId() external view returns (uint48) {
        return _getStorage().shareClasses[1].lastFeePaidId;
    }

    function shareSeriesId() external view returns (uint32) {
        return _getStorage().shareClasses[1].shareSeriesId;
    }

    function lastConsolidatedSeriesId() external view returns (uint32) {
        return _getStorage().shareClasses[1].lastConsolidatedSeriesId;
    }

    function timelocks(bytes4 _key) external view returns (TimelockRegistry.Timelock memory) {
        return _getStorage().timelocks[_key];
    }
}
