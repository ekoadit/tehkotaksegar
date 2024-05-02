// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Escrow.sol";
import "./IERC20.sol";

contract TokenEscrow {
    Escrow public escrowContract;
    IERC20 public token;

    constructor(address _escrowContract, address _token) {
        escrowContract = Escrow(_escrowContract);
        token = IERC20(_token);
    }

    function depositTokens(uint256 _transactionId, uint256 _amount) external {
        require(_amount > 0, "Deposit amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        token.approve(address(escrowContract), _amount);
        escrowContract.deposit(_transactionId);
    }

    function releaseTokens(uint256 _transactionId) external {
        escrowContract.release(_transactionId);
        // Additional logic for releasing tokens to the payee
        // You can implement your own token transfer logic here
    }

    function startDispute(uint256 _transactionId) external {
        escrowContract.startDispute(_transactionId);
        // Additional logic for starting a dispute, if needed
    }

    function resolveDispute(uint256 _transactionId) external {
        escrowContract.resolveDispute(_transactionId);
        // Additional logic for resolving a dispute, if needed
    }
}
