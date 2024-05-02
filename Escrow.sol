// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Escrow {
    address public payer;
    address public payee;
    address public arbiter;
    uint256 public amount;
    bool public released;
    bool public refunded;
    enum State { Created, Locked, InEscrow, Disputed, Resolved }

    struct Transaction {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        State state;
    }

    Transaction[] public transactions;

    event EscrowCreated(uint256 indexed transactionId, address indexed buyer, address indexed seller, address arbiter, uint256 amount);
    event DisputeStarted(uint256 indexed transactionId);
    event DisputeResolved(uint256 indexed transactionId);
    event FundsDeposited(uint256 indexed transactionId, address indexed depositor, uint256 amount);
    event FundReleased(uint256 indexed transactionId, address indexed receiver, uint256 amount);
    event FundRefunded(uint256 indexed transactionId, address indexed payer, uint256 amount);
    event ItemBought(uint256 indexed transactionId, address indexed buyer, uint256 amount);
    event ItemSold(uint256 indexed transactionId, address indexed seller, uint256 amount);
    event TokensStaked(address indexed staker, uint256 amount);
    event LiquidityAdded(address indexed provider, address indexed token, uint256 amount);
    event WalletConnected(address indexed user, address indexed wallet);

    modifier onlyPayer() {
        require(msg.sender == payer, "Only payer can perform this action");
        _;
    }

    modifier onlyPayee() {
        require(msg.sender == payee, "Only payee can perform this action");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can perform this action");
        _;
    }

    constructor(address _payee, address _arbiter) {
        payer = msg.sender;
        payee = _payee;
        arbiter = _arbiter;
        released = false;
        refunded = false;
    }

    function connectWallet() external {
        emit WalletConnected(msg.sender, tx.origin);
    }

    function createEscrow() external payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        transactions.push(Transaction({
            buyer: msg.sender,
            seller: payee,
            arbiter: arbiter,
            amount: msg.value,
            state: State.Created
        }));
        emit EscrowCreated(transactions.length - 1, msg.sender, payee, arbiter, msg.value);
    }

    function deposit(uint256 _transactionId) external payable {
        require(_transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(msg.sender == transaction.buyer || msg.sender == transaction.seller, "Unauthorized depositor");
        require(transaction.state == State.Created, "Transaction state is not Created");
        transaction.state = State.InEscrow;
        emit FundsDeposited(_transactionId, msg.sender, msg.value);
    }

    function release(uint256 _transactionId) external onlyPayee {
        require(_transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.state == State.InEscrow, "Transaction state is not InEscrow");
        payable(payee).transfer(transaction.amount);
        transaction.state = State.Locked;
        released = true;
        emit FundReleased(_transactionId, payee, transaction.amount);
    }

    function startDispute(uint256 _transactionId) external onlyArbiter {
        require(_transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.state == State.InEscrow || transaction.state == State.Locked, "Invalid transaction state");
        transaction.state = State.Disputed;
        emit DisputeStarted(_transactionId);
    }

    function resolveDispute(uint256 _transactionId) external onlyArbiter {
        require(_transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.state == State.Disputed, "Transaction is not in Disputed state");
        payable(payer).transfer(transaction.amount);
        transaction.state = State.Resolved;
        refunded = true;
        emit FundRefunded(_transactionId, payer, transaction.amount);
        emit DisputeResolved(_transactionId);
    }

    function buyItem(uint256 _transactionId) external onlyPayer {
        require(_transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.state == State.InEscrow, "Transaction state is not InEscrow");
        transaction.state = State.Locked;
        released = true;
        emit ItemBought(_transactionId, msg.sender, transaction.amount);
    }

    function sellItem(uint256 _transactionId) external onlyPayee {
        require(_transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[_transactionId];
        require(transaction.state == State.Created, "Transaction state is not Created");
        transaction.state = State.InEscrow;
        emit ItemSold(_transactionId, msg.sender, transaction.amount);
    }

    function stakeTokens(address token, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit TokensStaked(msg.sender, amount);
    }

    function addLiquidity(address token, uint256 amount) external payable {
        require(token != address(0), "Invalid token address");
        if (token == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH value not needed for token liquidity");
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
        emit LiquidityAdded(msg.sender, token, amount);
    }
}
