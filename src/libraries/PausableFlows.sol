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
library PausableFlows {
    bytes4 internal constant DEPOSIT_REQUEST_FLOW = bytes4(keccak256("DEPOSIT_REQUEST_FLOW"));
    bytes4 internal constant REDEEM_REQUEST_FLOW = bytes4(keccak256("REDEEM_REQUEST_FLOW"));
    bytes4 internal constant SETTLE_DEPOSIT_FLOW = bytes4(keccak256("SETTLE_DEPOSIT_FLOW"));
    bytes4 internal constant SETTLE_REDEEM_FLOW = bytes4(keccak256("SETTLE_REDEEM_FLOW"));
    bytes4 internal constant WITHDRAW_FLOW = bytes4(keccak256("WITHDRAW_FLOW"));
}
