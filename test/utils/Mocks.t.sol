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

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract Mocks is Test {
    /*//////////////////////////////////////////////////////////////
                        VAULT FACTORY MOCKS
    //////////////////////////////////////////////////////////////*/
    function mockIsValidVault(address _vaultFactory, address _vault, bool _returnValue) public {
        vm.mockCall(_vaultFactory, abi.encodeCall(IAlephVaultFactory.isValidVault, (_vault)), abi.encode(_returnValue));
    }

    /*//////////////////////////////////////////////////////////////
                        FEE MANAGER MOCKS
    //////////////////////////////////////////////////////////////*/
    function mockCollectFees(address _vault, uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect)
        public
    {
        vm.mockCall(
            _vault,
            abi.encodeCall(IFeeManager.collectFees, ()),
            abi.encode(_managementFeesToCollect, _performanceFeesToCollect)
        );
    }
}
