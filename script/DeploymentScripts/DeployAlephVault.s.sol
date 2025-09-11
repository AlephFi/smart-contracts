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

import {Script, console} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {BaseScript} from "@aleph-script/BaseScript.s.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to deploy a new AlephVault.
// forge script DeployAlephVault --sig="run()" --broadcast -vvvv --verify
contract DeployAlephVault is BaseScript {
    using MessageHashUtils for bytes32;

    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);

        string memory _environment = _getEnvironment();
        address _factory = _getFactoryProxy(_chainId, _environment);

        string memory _vaultName = vm.envString("VAULT_NAME");
        string memory _vaultConfigId = vm.envString("VAULT_CONFIG_ID");
        address _vaultManager = vm.envAddress("VAULT_MANAGER");
        AuthLibrary.AuthSignature memory _authSignature =
            _getAuthSignature(_factory, _vaultManager, _vaultName, _vaultConfigId);

        IAlephVault.ShareClassParams memory _shareClassParams = IAlephVault.ShareClassParams({
            managementFee: uint32(vm.envUint("VAULT_MANAGEMENT_FEE")),
            performanceFee: uint32(vm.envUint("VAULT_PERFORMANCE_FEE")),
            noticePeriod: uint48(vm.envUint("VAULT_NOTICE_PERIOD")),
            lockInPeriod: uint48(vm.envUint("VAULT_LOCK_IN_PERIOD")),
            minDepositAmount: vm.envUint("VAULT_MIN_DEPOSIT_AMOUNT"),
            maxDepositCap: vm.envUint("VAULT_MAX_DEPOSIT_CAP"),
            minRedeemAmount: vm.envUint("VAULT_MIN_REDEEM_AMOUNT"),
            minUserBalance: vm.envUint("VAULT_MIN_USER_BALANCE")
        });

        IAlephVault.UserInitializationParams memory _userInitializationParams = IAlephVault.UserInitializationParams({
            name: _vaultName,
            configId: _vaultConfigId,
            manager: _vaultManager,
            underlyingToken: vm.envAddress("VAULT_UNDERLYING_TOKEN"),
            custodian: vm.envAddress("VAULT_CUSTODIAN"),
            vaultTreasury: vm.envAddress("VAULT_TREASURY"),
            shareClassParams: _shareClassParams,
            authSignature: _authSignature
        });
        address _vault = IAlephVaultFactory(_factory).deployVault(_userInitializationParams);
        console.log("================================================");
        console.log("Vault deployed at", _vault);
        console.log("================================================");

        vm.stopBroadcast();
    }

    function _getAuthSignature(
        address _factory,
        address _vaultManager,
        string memory _vaultName,
        string memory _vaultConfigId
    ) internal view returns (AuthLibrary.AuthSignature memory) {
        bytes32 _authMessage =
            keccak256(abi.encode(_vaultManager, _factory, _vaultName, _vaultConfigId, block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        uint256 _authSignerPrivateKey = _getAuthSignerPrivateKey();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        return AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});
    }
}
