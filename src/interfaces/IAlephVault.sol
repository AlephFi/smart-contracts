// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
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

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IAlephVault {
    error InvalidInitializationParams();
    error InvalidAuthSigner();
    error InvalidShareClass();
    error InvalidShareSeries();
    error InvalidVaultFee();

    event IsDepositAuthEnabledSet(bool isDepositAuthEnabled);
    event IsSettlementAuthEnabledSet(bool isSettlementAuthEnabled);
    event VaultTreasurySet(address vaultTreasury);
    event ShareClassCreated(uint8 classId, ShareClassParams shareClassParams);

    struct InitializationParams {
        address operationsMultisig;
        address vaultFactory;
        address oracle;
        address guardian;
        address authSigner;
        address accountant;
        UserInitializationParams userInitializationParams;
        ModuleInitializationParams moduleInitializationParams;
    }

    struct UserInitializationParams {
        string name;
        string configId;
        address manager;
        address underlyingToken;
        address custodian;
        ShareClassParams shareClassParams;
        AuthLibrary.AuthSignature authSignature;
    }

    struct ModuleInitializationParams {
        address alephVaultDepositImplementation;
        address alephVaultRedeemImplementation;
        address alephVaultSettlementImplementation;
        address feeManagerImplementation;
        address migrationManagerImplementation;
    }

    struct ShareClassParams {
        uint32 managementFee;
        uint32 performanceFee;
        uint48 noticePeriod;
        uint48 lockInPeriod;
        uint256 minDepositAmount;
        uint256 maxDepositCap;
        uint256 minRedeemAmount;
        uint256 minUserBalance;
    }

    struct ShareClass {
        uint8 shareSeriesId;
        uint8 lastConsolidatedSeriesId;
        uint48 lastFeePaidId;
        uint48 depositSettleId;
        uint48 redeemSettleId;
        ShareClassParams shareClassParams;
        mapping(uint8 => ShareSeries) shareSeries;
        mapping(uint48 batchId => DepositRequests) depositRequests;
        mapping(uint48 batchId => RedeemRequests) redeemRequests;
        mapping(address user => uint48) userLockInPeriod;
    }

    struct ShareSeries {
        uint256 totalAssets;
        uint256 totalShares;
        uint256 highWaterMark;
        EnumerableSet.AddressSet users;
        mapping(address => uint256) sharesOf;
    }

    struct DepositRequests {
        uint256 totalAmountToDeposit;
        address[] usersToDeposit;
        mapping(address => uint256) depositRequest;
    }

    struct RedeemRequests {
        address[] usersToRedeem;
        mapping(address => uint256) redeemRequest;
    }

    // View functions

    /**
     * @notice Returns the name of the vault.
     * @return The name.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the manager of the vault.
     * @return The manager.
     */
    function manager() external view returns (address);

    /**
     * @notice Returns the oracle of the vault.
     * @return The oracle.
     */
    function oracle() external view returns (address);

    /**
     * @notice Returns the operations multisig of the vault.
     * @return The operations multisig.
     */
    function operationsMultisig() external view returns (address);

    /**
     * @notice Returns the guardian of the vault.
     * @return The guardian.
     */
    function guardian() external view returns (address);

    /**
     * @notice Returns the KYC authentication signer of the vault.
     * @return The KYC authentication signer.
     */
    function authSigner() external view returns (address);

    /**
     * @notice Returns the underlying token of the vault.
     * @return The underlying token.
     */
    function underlyingToken() external view returns (address);

    /**
     * @notice Returns the custodian of the vault.
     * @return The custodian.
     */
    function custodian() external view returns (address);

    /**
     * @notice Returns the vault treasury of the vault.
     * @return The vault treasury.
     */
    function vaultTreasury() external view returns (address);

    /**
     * @notice Returns the accountant of the vault.
     * @return The accountant.
     */
    function accountant() external view returns (address);

    /**
     * @notice Returns the management fee of the vault.
     * @param _classId The ID of the share class.
     * @return The management fee.
     */
    function managementFee(uint8 _classId) external view returns (uint32);

    /**
     * @notice Returns the performance fee of the vault.
     * @param _classId The ID of the share class.
     * @return The performance fee.
     */
    function performanceFee(uint8 _classId) external view returns (uint32);

    /**
     * @notice Returns the current batch ID based on the elapsed time since start.
     * @return The current batch ID.
     */
    function currentBatch() external view returns (uint48);

    /**
     * @notice Returns the number of share classes in the vault.
     * @return The number of share classes.
     */
    function shareClasses() external view returns (uint8);

    /**
     * @notice Returns the total assets currently held by the vault.
     * @return The total assets.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Returns the total shares currently issued by the vault.
     * @return The total shares.
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice Returns the total assets in the vault for a given class.
     * @param _classId The ID of the share class.
     * @return The total assets in the vault for the given class.
     */
    function totalAssetsOfClass(uint8 _classId) external view returns (uint256[] memory);

    /**
     * @notice Returns the total shares in the vault for a given class.
     * @param _classId The ID of the share class.
     * @return The total shares in the vault for the given class.
     */
    function totalSharesOfClass(uint8 _classId) external view returns (uint256[] memory);

    /**
     * @notice Returns the total assets in the vault for a given class.
     * @param _classId The ID of the share class.
     * @return The total assets in the vault for the given class.
     */
    function totalAssetsPerClass(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the total shares in the vault for a given class.
     * @param _classId The ID of the share class.
     * @return The total shares in the vault for the given class.
     */
    function totalSharesPerClass(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the total assets in the vault for a given series.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The total assets in the vault for the given series.
     */
    function totalAssetsPerSeries(uint8 _classId, uint8 _seriesId) external view returns (uint256);

    /**
     * @notice Returns the total shares in the vault for a given series.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The total shares in the vault for the given series.
     */
    function totalSharesPerSeries(uint8 _classId, uint8 _seriesId) external view returns (uint256);

    /**
     * @notice Returns the amount of assets claimable by a user based on their shares.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @param _user The address of the user.
     * @return The amount of assets claimable by the user.
     */
    function assetsOf(uint8 _classId, uint8 _seriesId, address _user) external view returns (uint256);

    /**
     * @notice Returns the number of shares owned by a user.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @param _user The address of the user.
     * @return The number of shares owned by the user.
     */
    function sharesOf(uint8 _classId, uint8 _seriesId, address _user) external view returns (uint256);

    /**
     * @notice Returns the current price per share of the vault.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The current price per share.
     */
    function pricePerShare(uint8 _classId, uint8 _seriesId) external view returns (uint256);

    /**
     * @notice Returns the current high water mark of the vault.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The current high water mark.
     */
    function highWaterMark(uint8 _classId, uint8 _seriesId) external view returns (uint256);

    /**
     * @notice Returns the notice period of the vault.
     * @param _classId The ID of the share class.
     * @return The notice period.
     */
    function noticePeriod(uint8 _classId) external view returns (uint48);

    /**
     * @notice Returns the lock in period of the vault.
     * @param _classId The ID of the share class.
     * @return The lock in period.
     */
    function lockInPeriod(uint8 _classId) external view returns (uint48);

    /**
     * @notice Returns the minimum deposit amount.
     * @param _classId The ID of the share class.
     * @return The minimum deposit amount of the share class.
     */
    function minDepositAmount(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the minimum user balance.
     * @param _classId The ID of the share class.
     * @return The minimum user balance of the share class.
     */
    function minUserBalance(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the maximum deposit cap.
     * @param _classId The ID of the share class.
     * @return The maximum deposit cap of the share class.
     */
    function maxDepositCap(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the minimum redeem amount.
     * @param _classId The ID of the share class.
     * @return The minimum redeem amount of the share class.
     */
    function minRedeemAmount(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the user lock in period.
     * @param _classId The ID of the share class.
     * @param _user The address of the user.
     * @return The user lock in period.
     */
    function userLockInPeriod(uint8 _classId, address _user) external view returns (uint48);

    /**
     * @notice Returns the total amount of unsettled deposit requests for a given class.
     * @param _classId The ID of the share class.
     * @return The total amount of unsettled deposit requests for the given class.
     * @dev Please note that this function will return the deposit amount for all batches including the current batch.
     * However, if these deposit requests are settled in this batch, the amount requested in this batch will NOT be settled.
     * It will be settled in the next settlement batch. So if you're using this function to check for the deposit request for settlement,
     * please be aware of this nuance.
     */
    function totalAmountToDeposit(uint8 _classId) external view returns (uint256);

    /**
     * @notice Returns the total amount of unsettled deposit requests for a given class at a given batch.
     * @param _classId The ID of the share class.
     * @param _batchId The ID of the batch.
     * @return The total amount of unsettled deposit requests for the given class at the given batch.
     */
    function totalAmountToDepositAt(uint8 _classId, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the deposit request of a user.
     * @param _classId The ID of the share class.
     * @param _user The user to query.
     * @return The deposit request of the user.
     */
    function depositRequestOf(uint8 _classId, address _user) external view returns (uint256);

    /**
     * @notice Returns the deposit request of a user at a given batch.
     * @param _classId The ID of the share class.
     * @param _user The user to query.
     * @param _batchId The ID of the batch.
     * @return The deposit request of the user at the given batch.
     */
    function depositRequestOfAt(uint8 _classId, address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the redeem request of a user.
     * @param _classId The ID of the share class.
     * @param _user The user to query.
     * @return The redeem request of the user.
     */
    function redeemRequestOf(uint8 _classId, address _user) external view returns (uint256);

    /**
     * @notice Returns the redeem request of a user at a given batch.
     * @param _classId The ID of the share class.
     * @param _user The user to query.
     * @param _batchId The ID of the batch.
     * @return The redeem request of the user at the given batch.
     */
    function redeemRequestOfAt(uint8 _classId, address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the users to deposit at a given batch.
     * @param _classId The ID of the share class.
     * @param _batchId The ID of the batch.
     * @return The users to deposit at the given batch.
     */
    function usersToDepositAt(uint8 _classId, uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the users to redeem at a given batch.
     * @param _classId The ID of the share class.
     * @param _batchId The ID of the batch.
     * @return The users to redeem at the given batch.
     */
    function usersToRedeemAt(uint8 _classId, uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the total fee amount to collect.
     * @return The total fee amount to collect.
     */
    function totalFeeAmountToCollect() external view returns (uint256);

    /**
     * @notice Returns whether authentication is enabled for deposits.
     * @return The status of the authentication for deposits.
     */
    function isDepositAuthEnabled() external view returns (bool);

    /**
     * @notice Returns whether authentication is enabled for settlements.
     * @return The status of the authentication for settlements.
     */
    function isSettlementAuthEnabled() external view returns (bool);

    /**
     * @notice Sets whether authentication is enabled for deposits.
     * @param _isDepositAuthEnabled The new status of the authentication for deposits.
     */
    function setIsDepositAuthEnabled(bool _isDepositAuthEnabled) external;

    /**
     * @notice Sets whether authentication is enabled for settlements.
     * @param _isSettlementAuthEnabled The new status of the authentication for settlements.
     */
    function setIsSettlementAuthEnabled(bool _isSettlementAuthEnabled) external;

    /**
     * @notice Sets the vault treasury.
     * @param _vaultTreasury The new vault treasury.
     */
    function setVaultTreasury(address _vaultTreasury) external;

    /**
     * @notice Creates a new share class.
     * @param _shareClassParams The parameters for the share class.
     */
    function createShareClass(ShareClassParams memory _shareClassParams) external returns (uint8 _classId);
}
