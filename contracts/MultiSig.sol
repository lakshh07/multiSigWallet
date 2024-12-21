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
    event TransferCreated(
        uint256 id,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 approvals,
        bool status,
        uint256 timeOfTransaction
    );
    event TransferCancelled(
        uint256 id,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 approvals,
        bool status,
        uint256 timeOfTransaction
    );
    event TransferApproved(
        uint256 id,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 approvals,
        bool status,
        uint256 timeOfTransaction
    );
    event TransferSent(
        uint256 id,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        bool status,
        uint256 timeOfTransaction
    );

    error NotOwner();
    error NotSender();
    error OwnerExists();
    error OwnerNotFound();
    error InvalidThreshold();
    error CannotRemoveMainOwner();
    error MinimumOwnerRequired();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidAddress();
    error WithdrawalFailed();
    error TransferNotFound();
    error TransferFailed();
    error InsufficientApprovals();

    address private immutable mainOwner;
    mapping(address => bool) public isOwner;
    mapping(address => uint256) public depositAmount;

    uint256 public threshold = (walletOwners.length / 2) + 1;
    uint96 private depositId;
    uint96 private withdrawId;
    uint96 private transferId;
    address[] private walletOwners;

    struct Transfer {
        uint256 id;
        address sender;
        address payable receiver;
        uint256 amount;
        uint256 approvals;
        uint256 timeOfTransaction;
        bool status;
    }

    mapping(uint256 => mapping(address => bool)) private transferApprovals;
    mapping(uint256 => Transfer) private transfers;

    constructor() {
        mainOwner = msg.sender;
        walletOwners.push(mainOwner);
        isOwner[mainOwner] = true;
    }

    modifier onlyOwners() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    /// @notice Sets the threshold for the number of approvals required for a transfer
    /// @param _threshold The new threshold value
    function setThreshold(uint256 _threshold) external onlyOwners {
        if (_threshold <= 0) revert InvalidThreshold();
        if (_threshold > walletOwners.length) revert InvalidThreshold();

        threshold = _threshold;
    }

    /// @notice Adds a wallet owner
    /// @param _owner The address of the owner to add
    function addWalletOwner(address _owner) external onlyOwners {
        if (_owner == address(0)) revert InvalidAddress();
        if (isOwner[_owner]) revert OwnerExists();

        isOwner[_owner] = true;
        walletOwners.push(_owner);

        emit WalletOwnerAdded(msg.sender, _owner, block.timestamp);
    }

    /// @notice Removes a wallet owner
    /// @param _owner The address of the owner to remove
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

    /// @notice Deposits funds into the contract
    function deposit() public payable {
        if (msg.value == 0) revert InvalidAmount();

        depositAmount[msg.sender] += msg.value;
        unchecked {}

        emit DepositMade(msg.sender, msg.value, depositId, block.timestamp);
        ++depositId;
    }

    /// @notice Withdraws funds from the contract
    /// @param _amount The amount of funds to withdraw
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

    /// @notice Creates a transfer
    /// @param _receiver The address of the receiver
    /// @param _amount The amount of the transfer
    function createTransfer(
        address payable _receiver,
        uint256 _amount
    ) external onlyOwners {
        if (depositAmount[msg.sender] < _amount) revert InsufficientBalance();
        if (address(this).balance < _amount) revert InsufficientBalance();
        if (msg.sender == _receiver) revert InvalidAddress();
        if (_receiver == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        depositAmount[msg.sender] -= _amount;

        Transfer storage newTransfer = transfers[transferId];
        newTransfer.id = transferId;
        newTransfer.sender = msg.sender;
        newTransfer.receiver = _receiver;
        newTransfer.amount = _amount;
        newTransfer.approvals = 0;
        newTransfer.timeOfTransaction = block.timestamp;

        unchecked {
            ++transferId;
        }

        emit TransferCreated(
            transferId,
            msg.sender,
            _receiver,
            _amount,
            0,
            false,
            block.timestamp
        );
    }

    /// @notice Approves the transfer
    /// @param _id The ID of the transfer to approve
    function approveTransfer(uint256 _id) external onlyOwners {
        Transfer storage transfer = transfers[_id];
        if (transfer.receiver == address(0)) revert TransferNotFound();
        if (transferApprovals[_id][msg.sender]) revert("Already approved");
        if (transfer.sender == msg.sender) revert("Sender cannot approve");

        transferApprovals[_id][msg.sender] = true;
        transfer.approvals += 1;

        emit TransferApproved(
            _id,
            transfer.sender,
            transfer.receiver,
            transfer.amount,
            transfer.approvals,
            false,
            block.timestamp
        );

        if (transfer.approvals >= threshold) {
            sendTransfer(_id);
        }
    }

    /// @notice Cancels a transfer
    /// @param _id The ID of the transfer to cancel
    function cancelTransfer(uint256 _id) external onlyOwners {
        Transfer storage transfer = transfers[_id];
        if (transfer.receiver == address(0)) revert TransferNotFound();
        if (transfer.sender != msg.sender) revert NotSender();

        depositAmount[transfer.sender] += transfer.amount;
        delete transfers[_id];

        emit TransferCancelled(
            _id,
            transfer.sender,
            transfer.receiver,
            transfer.amount,
            transfer.approvals,
            false,
            block.timestamp
        );
    }

    /// @notice Sends a transfer
    /// @param _id The ID of the transfer to send
    function sendTransfer(uint256 _id) private onlyOwners {
        Transfer storage transfer = transfers[_id];
        if (transfer.receiver == address(0)) revert TransferNotFound();
        if (transfer.approvals < walletOwners.length)
            revert InsufficientApprovals();

        transfer.status = true;
        (bool success, ) = transfer.receiver.call{value: transfer.amount}("");
        if (!success) revert TransferFailed();

        emit TransferSent(
            _id,
            transfer.sender,
            transfer.receiver,
            transfer.amount,
            true,
            block.timestamp
        );
    }

    /// @notice Returns all wallet owners
    /// @return Array of owner addresses
    function getWalletOwners() external view returns (address[] memory) {
        return walletOwners;
    }

    /// @notice Returns the deposited balance of the caller
    /// @return the deposited balance of the caller
    function getBalance() external view returns (uint256) {
        return depositAmount[msg.sender];
    }

    /// @notice Returns the total balance of the contract
    /// @return The total balance of the contract
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Returns the number of approvals for a transfer
    /// @param _id The ID of the transfer
    /// @return The number of approvals for the transfer
    function getTransferApprovals(uint256 _id) external view returns (uint256) {
        return transfers[_id].approvals;
    }

    /// @notice Returns all transfers as a struct array
    /// @return Array of Transfer structs containing transfer details
    function getAllTransfers() external view returns (Transfer[] memory) {
        Transfer[] memory transferList = new Transfer[](transferId);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < transferId; i++) {
            Transfer storage transfer = transfers[i];
            if (transfer.receiver != address(0)) {
                transferList[currentIndex] = transfer;
                currentIndex++;
            }
        }

        return transferList;
    }

    /// @notice Returns true if an owner has approved a transfer
    /// @param _id The ID of the transfer
    /// @param _owner The address of the owner
    /// @return True if the owner has approved the transfer, false otherwise
    function hasApprovedTransfer(
        uint256 _id,
        address _owner
    ) external view returns (bool) {
        return transferApprovals[_id][_owner];
    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }
}
