// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./MultiSig.sol";

contract MultiSigFactory {
    event WalletCreated(
        address indexed owner,
        address indexed wallet,
        uint256 indexed walletId
    );
    event WalletRemoved(
        address indexed owner,
        address indexed wallet,
        uint256 indexed walletId
    );

    error WalletNotFound();
    error MaxWalletsReached();

    uint96 private constant MAX_WALLETS_PER_USER = 10;
    uint96 private totalWallets;

    struct Wallet {
        uint96 id;
        address walletAddress;
    }

    mapping(address => Wallet[]) private userWallets;
    mapping(address => bool) private isWalletRegistered;

    /// @notice Create a new wallet for a user
    /// @dev Reverts if user has reached maximum wallet limit
    function createWallet() external {
        if (userWallets[msg.sender].length >= MAX_WALLETS_PER_USER) {
            revert MaxWalletsReached();
        }

        MultiSig newWallet = new MultiSig();
        address walletAddress = address(newWallet);
        uint96 walletId = totalWallets;

        userWallets[msg.sender].push(
            Wallet({id: walletId, walletAddress: walletAddress})
        );

        isWalletRegistered[walletAddress] = true;

        unchecked {
            ++totalWallets;
        }

        emit WalletCreated(msg.sender, walletAddress, walletId);
    }

    /// @notice Remove a wallet for a user
    /// @param _wallet The address of the wallet to remove
    function removeWallet(address _wallet) external {
        if (!isWalletRegistered[_wallet]) {
            revert WalletNotFound();
        }

        Wallet[] storage wallets = userWallets[msg.sender];
        uint256 length = wallets.length;

        for (uint256 i = 0; i < length; ) {
            if (wallets[i].walletAddress == _wallet) {
                uint96 walletId = wallets[i].id;

                if (i != length - 1) {
                    wallets[i] = wallets[length - 1];
                }
                wallets.pop();

                isWalletRegistered[_wallet] = false;

                unchecked {
                    --totalWallets;
                }

                emit WalletRemoved(msg.sender, _wallet, walletId);
                return;
            }
            unchecked {
                ++i;
            }
        }

        revert WalletNotFound();
    }

    /// @notice Get all wallets for the caller
    /// @return Array of wallets owned by the caller
    function getWallets() external view returns (Wallet[] memory) {
        return userWallets[msg.sender];
    }

    /// @notice Check if a wallet address exists
    /// @param _wallet The wallet address to check
    /// @return bool indicating if wallet exists
    function isWallet(address _wallet) external view returns (bool) {
        return isWalletRegistered[_wallet];
    }

    /// @notice Get the total number of wallets across all users
    /// @return The total number of wallets
    function getTotalWallets() external view returns (uint96) {
        return totalWallets;
    }

    /// @notice Get number of wallets for the caller
    /// @return Number of wallets owned by caller
    function getWalletCount() external view returns (uint256) {
        return userWallets[msg.sender].length;
    }
}
