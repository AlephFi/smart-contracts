// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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

import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {IMigrationManager} from "@aleph-vault/interfaces/IMigrationManager.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 * @notice Complete interface for AlephVault including all module functionality
 */
interface IAlephVaultFull is
    IAlephPausable,
    IAlephVault,
    IAlephVaultDeposit,
    IAlephVaultRedeem,
    IAlephVaultSettlement,
    IFeeManager,
    IMigrationManager
{}
