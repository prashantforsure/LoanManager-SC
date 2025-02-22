// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract LoanManager {

    address private _owner;
    
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
   
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    error ReentrancyGuardReentrantCall();
// loan struct hai yeah 
    struct Loan {
        address borrower;       
        uint256 principal;      
        uint256 interestRate;   
        uint256 totalRepayable;
        uint256 amountRepaid;  
        bool approved;         
        bool repaid;          
        uint256 createdAt;      
        uint256 dueDate;       
    }
  
    uint256 public loanCount;
    mapping(uint256 => Loan) public loans;
//loan event for the frontend for the notification and all 
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principal,
        uint256 interestRate,
        uint256 dueDate
    );

    event LoanApproved(
        uint256 indexed loanId,
        uint256 totalRepayable
    );
    // this is the event for the loan owner
    event LoanRepaid(
        uint256 indexed loanId,
        uint256 amount,
        uint256 totalRepaid,
        bool fullyRepaid
    );

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _owner = initialOwner;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    function createLoan(uint256 principal, uint256 interestRate, uint256 dueDate) external {
        require(principal > 0, "Principal must be greater than zero");
        require(interestRate > 0, "Interest rate must be greater than zero");
        require(dueDate > block.timestamp, "Due date must be in the future");

        loanCount++;
        loans[loanCount] = Loan({
            borrower: msg.sender,
            principal: principal,
            interestRate: interestRate,
            totalRepayable: 0,   
            amountRepaid: 0,
            approved: false,
            repaid: false,
            createdAt: block.timestamp,
            dueDate: dueDate
        });

        emit LoanCreated(loanCount, msg.sender, principal, interestRate, dueDate);
    }

    function approveLoan(uint256 loanId) external onlyOwner {
        Loan storage loan = loans[loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(!loan.approved, "Loan already approved");
        require(block.timestamp < loan.dueDate, "Loan due date has passed");

        loan.approved = true;
        loan.totalRepayable = loan.principal + ((loan.principal * loan.interestRate) / 100);

        emit LoanApproved(loanId, loan.totalRepayable);
    }

    function repayLoan(uint256 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.approved, "Loan not approved yet");
        require(!loan.repaid, "Loan already repaid");
        require(msg.sender == loan.borrower, "Only borrower can repay");
        require(msg.value > 0, "Repayment amount must be greater than zero");

        uint256 remaining = loan.totalRepayable - loan.amountRepaid;
        uint256 payment = msg.value;

        if (payment > remaining) {
            uint256 refund = payment - remaining;
            payment = remaining;
            (bool refundSuccess, ) = msg.sender.call{value: refund}("");
            require(refundSuccess, "Refund failed");
        }

        loan.amountRepaid += payment;

        bool fullyRepaid = false;
        if (loan.amountRepaid >= loan.totalRepayable) {
            loan.repaid = true;
            fullyRepaid = true;
        }

        emit LoanRepaid(loanId, payment, loan.amountRepaid, fullyRepaid);
    }

    function getLoanDetails(uint256 loanId) external view returns (Loan memory) {
        require(loans[loanId].borrower != address(0), "Loan does not exist");
        return loans[loanId];
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient contract balance");
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
    
    fallback() external payable {}
}