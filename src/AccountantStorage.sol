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

/**
 * @notice Data layout for the accountant storage.
 * @param operationsMultisig The operations multisig address.
 * @param vaultFactory The vault factory address.
 * @param alephTreasury The aleph treasury address.
 * @param managementFeeCut The management fee cut for each vault.
 * @param performanceFeeCut The performance fee cut for each vault.
 * @param vaultTreasury The vault treasury for each vault.
 */
struct AccountantStorageData {
    address operationsMultisig;
    address vaultFactory;
    address alephTreasury;
    mapping(address vault => uint32) managementFeeCut;
    mapping(address vault => uint32) performanceFeeCut;
    mapping(address vault => address) vaultTreasury;
}
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

library AccountantStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.accountant")) - 1;

    function load() internal pure returns (AccountantStorageData storage sd) {
        uint256 _position = STORAGE_POSITION;
        assembly {
            sd.slot := _position
        }
    }
}
