//SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

contract MultiSig {
    event WalletOwnerAdded(
        address indexed addedBy,
        address indexed ownerAdded,
        uint256 timeOfTransaction
    );
    event WalletOwnerRemoved(
        address indexed removedBy,
        address indexed ownerRemoved,
        uint256 timeOfTransaction
    );
    event DepositMade(
        address indexed depositor,
        uint256 amount,
        uint256 depositId,
        uint256 timeOfTransaction
    );
    event WithdrawMade(
        address indexed withdrawer,
        uint256 amount,
        uint256 withdrawId,
        uint256 timeOfTransaction
    );

    error NotOwner();
    error OwnerExists();
    error OwnerNotFound();
    error CannotRemoveMainOwner();
    error MinimumOwnerRequired();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidAddress();
    error WithdrawalFailed();

    address private immutable mainOwner;
    mapping(address => bool) public isOwner;
    mapping(address => uint256) public depositAmount;

    uint96 private depositId;
    uint96 private withdrawId;

    address[] private walletOwners;

    constructor() {
        mainOwner = msg.sender;
        walletOwners.push(mainOwner);
        isOwner[mainOwner] = true;
    }

    modifier onlyOwners() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    function addWalletOwner(address _owner) external onlyOwners {
        if (_owner == address(0)) revert InvalidAddress();
        if (isOwner[_owner]) revert OwnerExists();

        isOwner[_owner] = true;
        walletOwners.push(_owner);

        emit WalletOwnerAdded(msg.sender, _owner, block.timestamp);
    }

    function removeWalletOwner(address _owner) external onlyOwners {
        if (_owner == mainOwner) revert CannotRemoveMainOwner();
        if (!isOwner[_owner]) revert OwnerNotFound();
        if (walletOwners.length <= 1) revert MinimumOwnerRequired();

        uint256 lastIndex = walletOwners.length - 1;
        for (uint256 i = 0; i < lastIndex; ++i) {
            if (walletOwners[i] == _owner) {
                walletOwners[i] = walletOwners[lastIndex];
                break;
            }
        }
        walletOwners.pop();
        isOwner[_owner] = false;

        emit WalletOwnerRemoved(msg.sender, _owner, block.timestamp);
    }

    function deposit() public payable {
        if (msg.value == 0) revert InvalidAmount();

        depositAmount[msg.sender] += msg.value;
        unchecked {}

        emit DepositMade(msg.sender, msg.value, depositId, block.timestamp);
        ++depositId;
    }

    function withdraw(uint256 _amount) external onlyOwners {
        if (_amount == 0) revert InvalidAmount();

        uint256 userBalance = depositAmount[msg.sender];
        if (userBalance < _amount) revert InsufficientBalance();
        if (address(this).balance < _amount) revert InsufficientBalance();

        depositAmount[msg.sender] = userBalance - _amount;

        unchecked {
            ++withdrawId;
        }

        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert WithdrawalFailed();

        emit WithdrawMade(msg.sender, _amount, withdrawId, block.timestamp);
    }

    /// @notice Returns all wallet owners
    /// @return Array of owner addresses
    function getWalletOwners() external view returns (address[] memory) {
        return walletOwners;
    }

    /// @notice Returns the deposited balance of the caller
    function getBalance() external view returns (uint256) {
        return depositAmount[msg.sender];
    }

    /// @notice Returns the total balance of the contract
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }
}
