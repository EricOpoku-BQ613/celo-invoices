//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";

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

contract CeloInvoice {
    using Counters for Counters.Counter;

    event InvoiceCreated(
        uint indexed index,
        string number,
        address indexed creator,
        address indexed payer,
        uint total
    );
    event InvoiceProccessed(
        uint indexed index,
        address indexed creator,
        address indexed payer,
        uint total
    );

    modifier onlyOwner(uint index) {
        require(
            _creators[index] != address(0),
            "You can't access this invoice"
        );
        _;
    }

    address owner;

    address internal cUsdTokenAddress =
        0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    Counters.Counter invoiceIndex;

    constructor() {
        owner = msg.sender;
    }

    enum InvoiceStatus {
        PENDING,
        PAYED,
        DECLINED
    }

    struct Invoice {
        InvoiceStatus status;
        string name;
        string number;
        string description;
        uint total;
        Item[] items;
        address payer;
        uint64 dateDue;
    }

    struct Item {
        string name;
        uint price;
    }

    //all generated invoices
    mapping(uint => Invoice) allInvoices;

    //map of creator to list of owned invoices;
    mapping(address => mapping(uint => uint)) _ownedInvoices;

    //map of creator to list of owned invoices;
    mapping(address => mapping(uint => uint)) _processInvoices;

    // tracks the number of invoices to process
    mapping(address => uint) _receivedInvoices;

    // tracks the number of invoices created
    mapping(address => uint) _issuedInvoices;

    // map invoice id to owner
    mapping(uint => address) _creators;

    function generateInvoice(
        string calldata _number,
        string calldata _name,
        string calldata _description,
        Item[] calldata _items,
        uint _total,
        address _payer,
        uint64 _dateDue
    ) external {
        uint _index = invoiceIndex.current();
       
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

       // number of issued invoices of creator
        uint creatorInvoiceCount = getOwnedInvoiceCount(msg.sender);

        // number of issued invoices of payer
        uint processInvoiceCount = getReceivedInvoiceCount(_payer);

        _issuedInvoices[msg.sender] += 1;
        _receivedInvoices[_payer] += 1;

        _creators[_index] = msg.sender;
        _ownedInvoices[msg.sender][creatorInvoiceCount] = _index;

        _processInvoices[_payer][processInvoiceCount] = _index;

    }

    function addInvoice( uint _index, string calldata _number,
        string calldata _name,
        string calldata _description,
        Item[] calldata _items,
        uint _total,
        address _payer,
        uint64 _dateDue) internal {

         Invoice storage newInvoice = allInvoices[_index];
        newInvoice.name = _name;
        newInvoice.number = _number;
        newInvoice.description = _description;
        newInvoice.total = _total;
        newInvoice.payer = _payer;
        newInvoice.dateDue = _dateDue;
        newInvoice.status = InvoiceStatus.PENDING;

        for (uint idx = 0; idx < _items.length; idx++) {
            newInvoice.items.push(_items[idx]);
        }

        invoiceIndex.increment();

        emit InvoiceCreated(_index, _number, msg.sender, _payer, _total);
    }
    function getOwnedInvoiceCount(address _address) public view returns (uint) {
        return _issuedInvoices[_address];
    }

    function getReceivedInvoiceCount(address _address)
        public
        view
        returns (uint)
    {
        return _receivedInvoices[_address];
    }

    function getOwnedInvoices(uint index)
        external
        view
        returns (
            uint,
            string memory,
            string memory,
            string memory,
            uint,
            Item[] memory,
            address,
            InvoiceStatus,
            uint64
        )
    {
        require(index < invoiceIndex.current(), "unknown invoice");
        uint _invoiceIndex = _ownedInvoices[msg.sender][index];
        Invoice memory invoice = allInvoices[_invoiceIndex];
        
        return (           
            index,
            invoice.number,
            invoice.name,
            invoice.description,
            invoice.total,
            invoice.items,
            invoice.payer,
            invoice.status,
            invoice.dateDue
        );
    }

    function getReceivedInvoice(uint _index)
        external
        view
        returns (
            uint,
            string memory,
            string memory,
            string memory,
            uint,
            Item[] memory,
            address,
            address,
            InvoiceStatus,
            uint64
        )
    {
        require(_index < invoiceIndex.current(), "unknown invoice");
        uint _invoiceIndex = _processInvoices[msg.sender][_index];
        Invoice memory invoice = allInvoices[_invoiceIndex];
        address _owner = _creators[_invoiceIndex];

        return (
            _index,
            invoice.number,
            invoice.name,
            invoice.description,
            invoice.total,
            invoice.items,
            _owner,
            invoice.payer,
            invoice.status,
            invoice.dateDue
        );
    }

    function makeInvoicePayment(uint _index) external {
        uint _invoiceIndex = _processInvoices[msg.sender][_index];
        address creator = _creators[_index];

        Invoice storage invoice = allInvoices[_invoiceIndex];
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

    function declineInvoice(uint _index) external {
        uint _invoiceIndex = _processInvoices[msg.sender][_index];
        Invoice storage invoice = allInvoices[_invoiceIndex];

        invoice.status = InvoiceStatus.DECLINED;
    }

    function deleteInvoice(uint _index) external {
        uint _invoiceIndex = _ownedInvoices[msg.sender][_index];

        _issuedInvoices[msg.sender] -= 1;

        delete allInvoices[_invoiceIndex];
        delete _ownedInvoices[msg.sender][_index];
    }
}
