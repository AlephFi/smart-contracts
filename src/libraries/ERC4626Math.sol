// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @dev This library adds helper functions for ERC4626 math operations.
 */
library ERC4626Math {
    using Math for uint256;

    uint256 public constant TOTAL_SHARE_UNITS = 1e18;

    function previewDeposit(uint256 assets, uint256 totalShares, uint256 totalAssets) internal pure returns (uint256) {
        return convertToShares(assets, totalShares, totalAssets, Math.Rounding.Floor);
    }

    function previewMint(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return convertToAssets(shares, totalAssets, totalShares, Math.Rounding.Ceil);
    }

    function previewWithdraw(uint256 assets, uint256 totalShares, uint256 totalAssets)
        internal
        pure
        returns (uint256)
    {
        return convertToShares(assets, totalShares, totalAssets, Math.Rounding.Ceil);
    }

    function previewRedeem(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return convertToAssets(shares, totalAssets, totalShares, Math.Rounding.Floor);
    }

    function previewMintUnits(uint256 shareUnits, uint256 totalAssets) internal pure returns (uint256) {
        return convertToAssets(shareUnits, totalAssets);
    }

    function previewWithdrawUnits(uint256 assets, uint256 totalAssets) internal pure returns (uint256) {
        return convertToShareUnits(assets, totalAssets);
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function convertToShares(uint256 assets, uint256 totalShares, uint256 totalAssets, Math.Rounding rounding)
        internal
        pure
        returns (uint256)
    {
        return assets.mulDiv(totalShares + 10 ** _decimalsOffset(), totalAssets + 1, rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function convertToAssets(uint256 shares, uint256 totalAssets, uint256 totalShares, Math.Rounding rounding)
        internal
        pure
        returns (uint256)
    {
        return shares.mulDiv(totalAssets + 1, totalShares + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @dev Internal conversion function (from assets to share units) with support for rounding direction.
     */
    function convertToShareUnits(uint256 assets, uint256 totalAssets) internal pure returns (uint256) {
        return assets.mulDiv(TOTAL_SHARE_UNITS, totalAssets, Math.Rounding.Floor);
    }

    /**
     * @dev Internal conversion function (from share units to assets) with support for rounding direction.
     */
    function convertToAssets(uint256 shareUnits, uint256 totalAssets) internal pure returns (uint256) {
        return shareUnits.mulDiv(totalAssets, TOTAL_SHARE_UNITS, Math.Rounding.Ceil);
    }

    function _decimalsOffset() private pure returns (uint8) {
        return 0;
    }
}
