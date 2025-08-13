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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
interface IAlephVault {
    error InvalidInitializationParams();
    error InvalidAuthSigner();

    event MetadataUriSet(string metadataUri);
    event IsAuthEnabledSet(bool isAuthEnabled);
    event AuthSignerSet(address authSigner);

    struct InitializationParams {
        address operationsMultisig;
        address vaultFactory;
        address oracle;
        address guardian;
        address authSigner;
        address feeRecipient;
        uint32 managementFee;
        uint32 performanceFee;
        UserInitializationParams userInitializationParams;
        ModuleInitializationParams moduleInitializationParams;
    }

    struct UserInitializationParams {
        string name;
        string configId;
        address manager;
        address underlyingToken;
        address custodian;
    }

    struct ModuleInitializationParams {
        address alephVaultDepositImplementation;
        address alephVaultRedeemImplementation;
        address alephVaultSettlementImplementation;
        address feeManagerImplementation;
    }

    struct BatchData {
        uint48 batchId;
        uint256 totalAmountToDeposit;
        uint256 totalSharesToRedeem;
        address[] usersToDeposit;
        address[] usersToRedeem;
        mapping(address => uint256) depositRequest;
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
     * @notice Returns the fee recipient of the vault.
     * @return The fee recipient.
     */
    function feeRecipient() external view returns (address);

    /**
     * @notice Returns the management fee of the vault.
     * @return The management fee.
     */
    function managementFee() external view returns (uint32);

    /**
     * @notice Returns the performance fee of the vault.
     * @return The performance fee.
     */
    function performanceFee() external view returns (uint32);

    /**
     * @notice Returns the current batch ID based on the elapsed time since start.
     * @return The current batch ID.
     */
    function currentBatch() external view returns (uint48);

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
     * @notice Returns the total assets at a specific timestamp.
     * @param _timestamp The timestamp to query.
     * @return The total assets at the given timestamp.
     */
    function assetsAt(uint48 _timestamp) external view returns (uint256);

    /**
     * @notice Returns the amount of assets claimable by a user based on their shares.
     * @param _user The address of the user.
     * @return The amount of assets claimable by the user.
     */
    function assetsOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the amount of assets claimable by a user at a specific timestamp.
     * @param _user The address of the user.
     * @param _timestamp The timestamp to query.
     * @return The amount of assets claimable by the user at the given timestamp.
     */
    function assetsOfAt(address _user, uint48 _timestamp) external view returns (uint256);

    /**
     * @notice Returns the total shares at a specific timestamp.
     * @param _timestamp The timestamp to query.
     * @return The total shares at the given timestamp.
     */
    function sharesAt(uint48 _timestamp) external view returns (uint256);

    /**
     * @notice Returns the number of shares owned by a user.
     * @param _user The address of the user.
     * @return The number of shares owned by the user.
     */
    function sharesOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the number of shares owned by a user at a specific timestamp.
     * @param _user The address of the user.
     * @param _timestamp The timestamp to query.
     * @return The number of shares owned by the user at the given timestamp.
     */
    function sharesOfAt(address _user, uint48 _timestamp) external view returns (uint256);

    /**
     * @notice Returns the current price per share of the vault.
     * @return The current price per share.
     */
    function pricePerShare() external view returns (uint256);

    /**
     * @notice Returns the price per share at a specific timestamp.
     * @param _timestamp The timestamp to query.
     * @return The price per share at the given timestamp.
     */
    function pricePerShareAt(uint48 _timestamp) external view returns (uint256);

    /**
     * @notice Returns the current high water mark of the vault.
     * @return The current high water mark.
     */
    function highWaterMark() external view returns (uint256);

    /**
     * @notice Returns the high water mark at a specific timestamp.
     * @param _timestamp The timestamp to query.
     * @return The high water mark at the given timestamp.
     */
    function highWaterMarkAt(uint48 _timestamp) external view returns (uint256);

    /**
     * @notice Returns the minimum deposit amount.
     * @return The minimum deposit amount.
     */
    function minDepositAmount() external view returns (uint256);

    /**
     * @notice Returns the maximum deposit cap.
     * @return The maximum deposit cap.
     */
    function maxDepositCap() external view returns (uint256);

    /**
     * @notice Returns the total amount of unsettled deposit requests.
     * @return The total amount of unsettled deposit requests.
     * @dev Please note that this function will return the deposit amount for all batches including the current batch.
     * However, if these deposit requests are settled in this batch, the amount requested in this batch will NOT be settled.
     * It will be settled in the next settlement batch. So if you're using this function to check if the deposit request for settlement,
     * please be aware of this nuance.
     */
    function totalAmountToDeposit() external view returns (uint256);

    /**
     * @notice Returns the total amount of deposit requests at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The total amount of deposit requests at the given batch ID.
     */
    function totalAmountToDepositAt(uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the users that have requested to deposit at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The users that have requested to deposit at the given batch ID.
     */
    function usersToDepositAt(uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the deposit request of a user.
     * @param _user The user to query.
     * @return The deposit request of the user.
     */
    function depositRequestOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the deposit request of a user at a specific batch ID.
     * @param _user The user to query.
     * @param _batchId The batch ID to query.
     * @return The deposit request of the user at the given batch ID.
     */
    function depositRequestOfAt(address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the total shares to redeem at the current batch.
     * @return The total shares to redeem at the current batch.
     */
    function totalSharesToRedeem() external view returns (uint256);

    /**
     * @notice Returns the total shares to redeem at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The total shares to redeem at the given batch ID.
     */
    function totalSharesToRedeemAt(uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the users that have requested to redeem at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The users that have requested to redeem at the given batch ID.
     */
    function usersToRedeemAt(uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the redeem request of a user.
     * @param _user The user to query.
     * @return The redeem request of the user.
     */
    function redeemRequestOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the redeem request of a user at a specific batch ID.
     * @param _user The user to query.
     * @param _batchId The batch ID to query.
     * @return The redeem request of the user at the given batch ID.
     */
    function redeemRequestOfAt(address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the total amount for redemption.
     * @param _newTotalAssets The new total assets before settlement.
     * @return The total amount for redemption.
     * @dev Please note that this function will return the redemption amount for all batches including the current batch.
     * However, if these redemption requests are settled in this batch, the amount requested in this batch will NOT be settled.
     * It will be settled in the next settlement batch. So if you're using this function to check if the redemption request for settlement,
     * please be aware of this nuance.
     */
    function totalAmountForRedemption(uint256 _newTotalAssets) external returns (uint256);

    /**
     * @notice Returns the status of the KYC authentication.
     * @return The status of the KYC authentication.
     */
    function isAuthEnabled() external view returns (bool);

    /**
     * @notice Returns the metadata URL of the vault.
     * @return The metadata URL.
     */
    function metadataUri() external view returns (string memory);

    /**
     * @notice Sets the metadata URL of the vault.
     * @param _metadataUrl The new metadata URL.
     */
    function setMetadataUri(string calldata _metadataUrl) external;

    /**
     * @notice Sets the status of the KYC authentication.
     * @param _isAuthEnabled The new status of the KYC authentication.
     */
    function setIsAuthEnabled(bool _isAuthEnabled) external;

    /**
     * @notice Sets the KYC authentication signer of the vault.
     * @param _authSigner The new KYC authentication signer.
     */
    function setAuthSigner(address _authSigner) external;

    /**
     * @notice Migrates the implementation of a module.
     * @param _module The module to migrate.
     * @param _newImplementation The new implementation.
     */
    function migrateModules(bytes4 _module, address _newImplementation) external;
}
