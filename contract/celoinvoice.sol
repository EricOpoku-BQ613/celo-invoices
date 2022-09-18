//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Token {
    function transfer(address, uint256) external returns (bool);

    function approve(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract CeloInvoice is Ownable {
    using Counters for Counters.Counter;

    event InvoiceCreated(
        uint256 indexed index,
        string number,
        address indexed creator,
        address indexed payer,
        uint256 total
    );
    event InvoiceProccessed(
        uint256 indexed index,
        address indexed creator,
        address indexed payer,
        uint256 total
    );

    address internal cUsdTokenAddress =
        0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    Counters.Counter private invoiceIndex;

    enum InvoiceStatus {
        UNDEFINED,
        PENDING,
        PAYED,
        DECLINED
    }

    struct Invoice {
        InvoiceStatus status;
        string name;
        string number;
        string description;
        uint256 total;
        Item[] items;
        address payer;
        uint64 dateDue;
    }

    struct Item {
        string name;
        uint256 price;
    }

    //all generated invoices
    mapping(uint256 => Invoice) allInvoices;

    // tracks the number of invoices to process
    mapping(address => uint256) _receivedInvoices;

    // tracks the number of invoices created
    mapping(address => uint256) _issuedInvoices;

    // map invoice id to owner
    mapping(uint256 => address) _creators;

    modifier checkIfPayer(uint256 _index) {
        require(
            allInvoices[_index].payer == msg.sender,
            "You are not the invoice's recipient"
        );
        _;
    }

    modifier exists(uint256 _index) {
        require(
            allInvoices[_index].status != InvoiceStatus.UNDEFINED,
            "Query of nonexistent invoice"
        );
        _;
    }

    /**
     * @dev allow users to create an invoice of items bought
     * @notice input data can't be empty
     * @param _items an array of the struct Items containing the items the invoice is based off
     * @param _dateDue the time by which a user must pay this invoice
     */
    function generateInvoice(
        string calldata _number,
        string calldata _name,
        string calldata _description,
        Item[] calldata _items,
        uint256 _total,
        address _payer,
        uint64 _dateDue
    ) external {
        require(bytes(_number).length > 0, "Empty number");
        require(bytes(_name).length > 0, "Empty name");
        require(bytes(_description).length > 0, "Empty description");
        require(_items.length > 0, "No items found for invoice");
        require(_total > 0, "Total needs to be at least one wei");
        require(
            _payer != address(0),
            "Error: Address zero is not a valid address"
        );
        require(
            _dateDue > block.timestamp,
            "Date due has to be greater than the current time"
        );
        uint256 _index = invoiceIndex.current();
        invoiceIndex.increment();

        addInvoice(
            _index,
            _number,
            _name,
            _description,
            _items,
            _total,
            _payer,
            _dateDue
        );

        _issuedInvoices[msg.sender] += 1;
        _receivedInvoices[_payer] += 1;

        _creators[_index] = msg.sender;
    }

    function addInvoice(
        uint256 _index,
        string calldata _number,
        string calldata _name,
        string calldata _description,
        Item[] calldata _items,
        uint256 _total,
        address _payer,
        uint64 _dateDue
    ) internal {
        Invoice storage newInvoice = allInvoices[_index];
        newInvoice.name = _name;
        newInvoice.number = _number;
        newInvoice.description = _description;
        newInvoice.total = _total;
        newInvoice.payer = _payer;
        newInvoice.dateDue = _dateDue;
        newInvoice.status = InvoiceStatus.PENDING;

        for (uint256 idx = 0; idx < _items.length; ) {
            newInvoice.items.push(_items[idx]);
            // idx is already checked for every new cycle of the for loop by the for loop running condition
            unchecked {
                ++idx;
            }
        }

        emit InvoiceCreated(_index, _number, msg.sender, _payer, _total);
    }

    function getOwnedInvoiceCount(address _address)
        public
        view
        returns (uint256)
    {
        return _issuedInvoices[_address];
    }

    function getReceivedInvoiceCount(address _address)
        public
        view
        returns (uint256)
    {
        return _receivedInvoices[_address];
    }

    function getInvoice(uint256 _index)
        public
        view
        exists(_index)
        returns (Invoice memory)
    {
        return allInvoices[_index];
    }

    /**
     * @dev allow users to pay their due invoices
     * @notice only the payer address of the invoice can make the payment
     */
    function makeInvoicePayment(uint256 _index)
        external
        exists(_index)
        checkIfPayer(_index)
    {
        Invoice storage invoice = allInvoices[_index];
        require(
            invoice.status == InvoiceStatus.PENDING,
            "Invoice status is not pending"
        );
        address creator = _creators[_index];
        invoice.status = InvoiceStatus.PAYED;

        require(
            IERC20Token(cUsdTokenAddress).transferFrom(
                msg.sender,
                creator,
                invoice.total
            ),
            "Transfer failed."
        );
    }

    /**
     * @dev allow users to decline an invoice in case of certain situations such as fake invoices or scams
     * @notice only the payer address can decline an invoice
     */
    function declineInvoice(uint256 _index)
        external
        exists(_index)
        checkIfPayer(_index)
    {
        Invoice storage invoice = allInvoices[_index];

        invoice.status = InvoiceStatus.DECLINED;
    }

    /**
     * @dev allow invoices' creators to delete an invoice
     * @dev invoice's data will be removed
     * @notice only the invoice's creator can delete the invoice
     */
    function deleteInvoice(uint256 _index) external exists(_index) {
        require(
            _creators[_index] == msg.sender,
            "You are not the invoice's creator"
        );
        _issuedInvoices[msg.sender] -= 1;
        uint256 invoicesLength = invoiceIndex.current() - 1;
        invoiceIndex.decrement();
        allInvoices[_index] = allInvoices[invoicesLength];
        delete allInvoices[invoicesLength];
    }
}
