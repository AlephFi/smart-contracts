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
 * @notice Data layout for the aleph pausable storage.
 * @param flowsPauseStates The pause states for each pausable flow.
 */
struct AlephPausableStorageData {
    mapping(bytes4 _pausableFlow => bool isPaused) flowsPauseStates;
}
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

library AlephPausableStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.pausable.flows")) - 1;

    function load() internal pure returns (AlephPausableStorageData storage sd) {
        uint256 _position = STORAGE_POSITION;
        assembly {
            sd.slot := _position
        }
    }
}
