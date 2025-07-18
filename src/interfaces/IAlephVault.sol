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
    error InvalidConstructorParams();
    error InvalidInitializationParams();

    event MetadataUriSet(string metadataUri);

    struct ConstructorParams {
        address operationsMultisig;
        address oracle;
        address guardian;
        uint32 maxManagementFee;
        uint32 maxPerformanceFee;
        uint48 managementFeeTimelock;
        uint48 performanceFeeTimelock;
        uint48 feeRecipientTimelock;
    }

    struct InitializationParams {
        string name;
        address manager;
        address underlyingToken;
        address custodian;
        address feeRecipient;
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
     * @notice Returns the total amount of deposit requests at the current batch.
     * @return The total amount of deposit requests at the current batch.
     */
    function totalDepositRequests() external view returns (uint256);

    /**
     * @notice Returns the total shares to redeem at the current batch.
     * @return The total shares to redeem at the current batch.
     */
    function totalRedeemRequests() external view returns (uint256);

    /**
     * @notice Returns the total amount of deposit requests at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The total amount of deposit requests at the given batch ID.
     */
    function totalDepositRequestsAt(uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the total shares to redeem at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The total shares to redeem at the given batch ID.
     */
    function totalRedeemRequestsAt(uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the users that have requested to deposit at the current batch.
     * @return The users that have requested to deposit at the current batch.
     */
    function usersToDeposit() external view returns (address[] memory);

    /**
     * @notice Returns the users that have requested to redeem at the current batch.
     * @return The users that have requested to redeem at the current batch.
     */
    function usersToRedeem() external view returns (address[] memory);

    /**
     * @notice Returns the users that have requested to deposit at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The users that have requested to deposit at the given batch ID.
     */
    function usersToDepositAt(uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the users that have requested to redeem at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The users that have requested to redeem at the given batch ID.
     */
    function usersToRedeemAt(uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the amount of deposit requested by a user at the current batch.
     * @param _user The address of the user.
     * @return The amount of deposit requested by the user at the current batch.
     */
    function depositRequestOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the shares to redeem requested by a user at the current batch.
     * @param _user The address of the user.
     * @return The shares to redeem requested by the user at the current batch.
     */
    function redeemRequestOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the amount of deposit requested by a user at a specific batch ID.
     * @param _user The address of the user.
     * @param _batchId The batch ID to query.
     * @return The amount of deposit requested by the user at the given batch ID.
     */
    function depositRequestOfAt(address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the shares to redeem requested by a user at a specific batch ID.
     * @param _user The address of the user.
     * @param _batchId The batch ID to query.
     * @return The shares to redeem requested by the user at the given batch ID.
     */
    function redeemRequestOfAt(address _user, uint48 _batchId) external view returns (uint256);

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
}
