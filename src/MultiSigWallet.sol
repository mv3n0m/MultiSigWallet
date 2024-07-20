// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed signer, uint256 indexed txId);
    event Revoke(address indexed signer, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] public signers;
    mapping(address => bool) public isSigner;
    uint public threshold;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approvedTxs;

    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a valid signer");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Tx doesn't exist");
        _;
    }

    modifier txApproved(uint256 _txId) {
        require(approvedTxs[_txId][msg.sender], "Tx not yet approved");
        _;
    }

    modifier txNotApproved(uint256 _txId) {
        require(!approvedTxs[_txId][msg.sender], "Tx already approved");
        _;
    }

    modifier txNotExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Tx already executed");
        _;
    }

    constructor(address[] memory _signers, uint _threshold) {
        require(_signers.length != 0, "At least 1 signer required.");
        require(_threshold != 0 && _threshold <= _signers.length, "Invalid threshold value");

        for (uint i; i < _signers.length; i++) {
            address signer = _signers[i];

            require(signer != address(0), "Zero address signer not allowed.");
            require(!isSigner[signer], "Signer already exists");

            isSigner[signer] = true;
            signers.push(signer);
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint256 _value, bytes calldata _data) external onlySigner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        emit Submit(transactions.length - 1);
    }

    function approve(uint _txId) external onlySigner txExists(_txId) txNotApproved(_txId) txNotExecuted(_txId) {
        approvedTxs[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function execute(uint _txId) external onlySigner txExists(_txId) txNotExecuted(_txId) {
        require(_getApprovedCount(_txId) >= threshold, "Not enough approvals");

        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Execution failed");

        emit Execute(_txId);
    }

    function revoke(uint _txId) external onlySigner txApproved(_txId) txNotExecuted(_txId) {
        approvedTxs[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    function _getApprovedCount(uint _txId) private view returns (uint count) {
        for (uint i; i < signers.length; i++) {
            if (approvedTxs[_txId][signers[i]]) {
                count++;
            }
        }
    }
}
