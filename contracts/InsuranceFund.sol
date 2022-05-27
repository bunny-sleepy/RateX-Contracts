// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Utils/ERC20Helper.sol";
import "./Interface/IPool.sol";
import "./Interface/IERC20Minimal.sol";

contract InsuranceFund is Ownable, ERC20Helper {
    address public pool_address;
    uint256 constant PRICE_PRECISION = 1e6;
    uint256 constant RATE_PRECISION = 1e4;

    constructor(address _pool) {
        require(_pool != address(0), "Zero address detected");
        pool_address = _pool;
    }

    function TransferLiquidationBonus(uint256 notional_amount) external returns (uint256 bonus_amount) {
        require(msg.sender == pool_address, "You are not pool");
        IPool pool = IPool(pool_address);
        uint256 balance;
        {
            IERC20Minimal asset = IERC20Minimal(pool.asset_address());
            balance = asset.balanceOf(address(this));
            balance = balance * PRICE_PRECISION / (10 ** pool.asset_decimals());
        }
        // NOTE: improve bonus rule later
        uint256 amount_to_transfer;
        if (notional_amount < balance * 5) {
            bonus_amount = notional_amount / 10;
            amount_to_transfer = notional_amount * (10 ** pool.asset_decimals()) / PRICE_PRECISION / 10;
        } else {
            bonus_amount = balance / 2;
            amount_to_transfer = balance * (10 ** pool.asset_decimals()) / PRICE_PRECISION / 2;
        }
        TransferToken(pool.asset_address(), pool_address, amount_to_transfer);
    }
}