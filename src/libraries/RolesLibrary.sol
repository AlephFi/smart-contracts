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
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library RolesLibrary {
    /**
     * @notice The role for the oracle.
     */
    bytes4 internal constant ORACLE = bytes4(keccak256("ORACLE"));
    /**
     * @notice The role for the guardian.
     */
    bytes4 internal constant GUARDIAN = bytes4(keccak256("GUARDIAN"));
    /**
     * @notice The role for the manager.
     */
    bytes4 internal constant MANAGER = bytes4(keccak256("MANAGER"));
    /**
     * @notice The role for the operations multisig.
     */
    bytes4 internal constant OPERATIONS_MULTISIG = bytes4(keccak256("OPERATIONS_MULTISIG"));
    /**
     * @notice The role for the vault factory.
     */
    bytes4 internal constant VAULT_FACTORY = bytes4(keccak256("VAULT_FACTORY"));
    /**
     * @notice The role for the accountant.
     */
    bytes4 internal constant ACCOUNTANT = bytes4(keccak256("ACCOUNTANT"));
    /**
     * @notice The role for the aleph avs.
     */
    bytes4 internal constant ALEPH_AVS = bytes4(keccak256("ALEPH_AVS"));
}
