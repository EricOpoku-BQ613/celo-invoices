import Web3 from "web3";
import { newKitFromWeb3 } from "@celo/contractkit";
import BigNumber from "bignumber.js";
import celoinvoiceAbi from "../contract/celoinvoice.abi.json";
import erc20Abi from "../contract/erc20.abi.json";

const ERC20_DECIMALS = 18;
const CIcontractAddress = "0x03b03D867688a8b2388397F54aEbdE6D75a05878";
const cUSDContractAddress = "0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1";
const INVOICE_STATUS = ["PENDING", "PAID", "DECLINED"];

let kit;
let contract;
let invoices = [];

const connectCeloWallet = async function () {
    if (window.celo) {
        notification("⚠️ Please approve this DApp to use it.");
        try {
            await window.celo.enable();
            notificationOff();

            const web3 = new Web3(window.celo);
            kit = newKitFromWeb3(web3);

            const accounts = await kit.web3.eth.getAccounts();
            kit.defaultAccount = accounts[0];

            contract = await new kit.web3.eth.Contract(
                celoinvoiceAbi,
                CIcontractAddress
            );
        } catch (error) {
            notification(`⚠️ ${error}.`);
        }
    } else {
        notification("⚠️ Please install the CeloExtensionWallet.");
    }
};

const getBalance = async function () {
    const totalBalance = await kit.getTotalBalance(kit.defaultAccount);
    const cUSDBalance = totalBalance.cUSD.shiftedBy(-ERC20_DECIMALS).toFixed(2);
    document.querySelector("#balance").textContent = cUSDBalance;
};

const getOwnedInvoices = async function () {
    const _invoicesLength = await contract.methods
        .getOwnedInvoiceCount(kit.defaultAccount)
        .call();

    const _invoices = [];
    for (let i = 0; i < _invoicesLength; i++) {
        let _invoice = new Promise(async (resolve, reject) => {
            let p = await contract.methods.getOwnedInvoices(i).call();
            resolve({
                index: i,
                number: p[1],
                name: p[2],
                description: p[3],
                // image: p[2],
                total: new BigNumber(p[4]),
                items: p[5],
                payer: p[6],
                status: p[7],
                owner: kit.defaultAccount,
                dateDue: p[8],
            });
        });
        _invoices.push(_invoice);
    }
    const __invoices = await Promise.all(_invoices);
    if(!__invoices.length){
        return;
    }
    invoices.push(...__invoices);

    // renderInvoices(invoices);
};

const getReceivedInvoices = async function () {
    const _invoicesLength = await contract.methods
        .getReceivedInvoiceCount(kit.defaultAccount)
        .call();
    const _invoices = [];
    for (let i = 0; i < _invoicesLength; i++) {
        let _invoice = new Promise(async (resolve, reject) => {
            let p = await contract.methods.getReceivedInvoice(i).call();
            resolve({
                index: i,
                number: p[1],
                name: p[2],
                description: p[3],
                // image: p[2],
                total: new BigNumber(p[4]),
                items: p[5],
                owner: p[6],
                payer: p[7],
                status: p[8],
                dateDue: p[9],
            });
        });
        _invoices.push(_invoice);
    }
    const __invoices = await Promise.all(_invoices);
    if(!__invoices.length){
        return;
    }
    invoices.push(...__invoices);

    // renderInvoices(invoices);
};

async function approve(_price) {
    // console.log( CIcontractAddress)
    const cUSDContract = new kit.web3.eth.Contract(
        erc20Abi,
        cUSDContractAddress
    );

    const result = await cUSDContract.methods
        .approve(CIcontractAddress, _price)
        .send({ from: kit.defaultAccount });
    return result;
}

function clearInvoices() {
    const container = document.getElementById("invoiceContainer");
    container.innerHTML = "";
    invoices = [];
}

function renderInvoices() {
    console.log(invoices);
    const container = document.getElementById("invoiceContainer");

    if (!invoices) {
        container.innerHTML = "<h4>No invoice created yet</h4>";
        return;
    }

    invoices.forEach((_invoice) => {
        const newDiv = document.createElement("div");
        newDiv.className = "col-md-3";
        newDiv.innerHTML = invoiceTemplate(_invoice);
        container.appendChild(newDiv);
    });
}

function renderInvoiceItem() {
    const newDiv = document.createElement("div");
    newDiv.className = "itemWrapper col-12";
    newDiv.innerHTML = `<div class="row g-2">
  <div class="col">
      <input
          type="text"
          class="invoiceItems form-control mb-2"
          placeholder="Enter item name *"
          name="itemNames[]"
          required="true"
      />
  </div>
  <div class="col">
      <input
          type="number"
          class="invoiceItemPrices form-control mb-2"
          placeholder="Enter item price *"
          name="itemPrices[]"
          required="true"
          min="0.01"
          step="0.01"
      />
  </div>
  <div class="col-auto">
      <button
      type="button"
      class="btn-light rounded-pill btn-close"
  ></button>
  </div>
</div>`;
    document.getElementById("itemWrapper").appendChild(newDiv);
}

function invoiceItemsTemplate(_invoiceItems) {
    let listItems = `<li><h6 class="dropdown-header">Items list</h6></li>`;

    for (let item of _invoiceItems) {
        listItems += `<li class="d-flex justify-content-between align-items-center" ><a class="dropdown-item " >${item.name} <span class="text-muted">(${BigNumber(item.price).shiftedBy(-ERC20_DECIMALS).toFixed(2)} cUSD)</span></a></li>`;
    }
    const list = `<ul class="dropdown-menu dropend"> ${listItems} </ul>`;
    return list;
}

function invoiceTemplate(_invoice) {
    console.log(_invoice.owner.toLowerCase() === kit.defaultAccount.toLowerCase());
    return `
    <div class="card mb-4">
      <img class="card-img-top" src="${blockies
          .create({
              seed: _invoice.payer,
              size: 8,
              scale: 16,
          })
          .toDataURL()}" alt="...">
      <div class="position-absolute top-0 start-2 bg-warning mt-4 px-2 py-1 rounded-end">
        <button type="button" class="btn btn-ghost dropdown-toggle" data-bs-toggle="dropdown">${
            _invoice.items.length
        } Item(s)</button>
        ${invoiceItemsTemplate(_invoice.items)}
      </div>
      <div class="position-absolute top-0 end-0 bg-warning mt-4 px-2 py-1 rounded-start">
        ${_invoice.total.shiftedBy(-ERC20_DECIMALS).toFixed(2)} cUSD
      </div>
      <div class="card-body text-left p-4 position-relative">
        <div class="translate-middle-y position-absolute top-0">
        ${identiconTemplate(kit.defaultAccount)}
        </div>
        <h2 class="card-title fs-4 fw-bold mt-2">${_invoice.name}</h2>
        <p class="card-text mb-4" style="min-height: 82px">
          ${_invoice.description}             
        </p>
        <p class="card-text mt-4">
          <i class="bi bi-geo-alt-fill"></i>
          <span>${INVOICE_STATUS[_invoice.status] === "PAID" ? _invoice.owner.toLowerCase() === kit.defaultAccount.toLowerCase() ? "RECIEVED" : "PAID" : INVOICE_STATUS[_invoice.status]}</span>
        </p>
        <p>Issuer: ${_invoice.owner} </p>
        ${
            kit.defaultAccount.toLowerCase() === _invoice.payer.toLowerCase()
                ? `<div class="d-grid gap-2">
          <a class="btn btn-lg btn-outline-dark payBtn fs-6 p-3 ${
              INVOICE_STATUS[_invoice.status] == "PAID" ?  "disabled" : ""
          }" id=${_invoice.index} >
          ${
              INVOICE_STATUS[_invoice.status] == "PAID" ? "PAID" : "PAY"
          } ${_invoice.total.shiftedBy(-ERC20_DECIMALS).toFixed(2)} cUSD
          </a>
        </div>`
                : `<p>Payer: ${_invoice.payer} </p>`
        }
      </div>
    </div>
  `;
}

function identiconTemplate(_address) {
    const icon = blockies
        .create({
            seed: _address,
            size: 8,
            scale: 16,
        })
        .toDataURL();

    return `
    <div class="rounded-circle overflow-hidden d-inline-block border border-white border-2 shadow-sm m-0">
      <a href="https://alfajores-blockscout.celo-testnet.org/address/${_address}/transactions"
          target="_blank">
          <img src="${icon}" width="48" alt="${_address}">
      </a>
    </div>
    `;
}

function notification(_text) {
    document.querySelector(".alert").style.display = "block";
    document.querySelector("#notification").textContent = _text;
}

function notificationOff() {
    document.querySelector(".alert").style.display = "none";
}

window.addEventListener("load", async () => {
    notification("⌛ Loading...");
    await connectCeloWallet();
    await getBalance();
    await getOwnedInvoices();
    await getReceivedInvoices();
    renderInvoices();
    notificationOff();
});

document.newInvoiceForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    e.stopPropagation();
    const formData = new FormData(e.target);

    const itemNames = [];
    const itemPrices = [];
    const data = {};

    for (let el of formData.entries()) {
        if (el[0] == "itemPrices[]") {
            itemPrices.push(el[1]);
            continue;
        }

        if (el[0] == "itemNames[]") {
            itemNames.push(el[1]);
            continue;
        }

        data[el[0]] = el[1];
    }

    const invoiceItems = [];

    for (let idx in itemNames) {
        invoiceItems[idx] = Object.freeze({
            name: itemNames[idx],
            price: new BigNumber(itemPrices[idx].toString())
                .shiftedBy(ERC20_DECIMALS)
                .toString(),
        });
    }

    notification(`⌛ Adding "${data.name}"...`);
    try {
        const result = await contract.methods
            .generateInvoice(
                data.number,
                data.name,
                data.description,
                invoiceItems,
                new BigNumber(data.total).shiftedBy(ERC20_DECIMALS),
                data.payer,
                Date.parse(data.dueDate) / 1000
            )
            .send({ from: kit.defaultAccount });
            notification(`🎉 You successfully added "${data.name}".`);
            
    } catch (error) {
        console.log(error);
        notification(`⚠️ ${error}.`);
    }finally{
        clearInvoices();
        await getOwnedInvoices();
        await getReceivedInvoices();
        renderInvoices();
        await getBalance();
    }
});

document
    .querySelector("#invoiceContainer")
    .addEventListener("click", async (e) => {
        if (e.target.className.includes("payBtn")) {
            const index = e.target.id;
            notification("⌛ Waiting for payment approval...");
            
            e.target.className += " disabled";
            try {
                await approve(invoices[index].total);
                notification(
                    `⌛ Awaiting payment for "${invoices[index].name}"...`
                );
                const result = await contract.methods
                    .makeInvoicePayment(index)
                    .send({ from: kit.defaultAccount });
                notification(
                    `🎉 You successfully bought "${invoices[index].name}".`
                );
                clearInvoices();
                await getReceivedInvoices();
                await getOwnedInvoices();
                renderInvoices();
                await getBalance();
                
            } catch (error) {
                console.log(error);
                notification(`⚠️ ${error}.`);
            } finally {
                e.target.className = e.target.className.replace("disabled", "");
            }
        }
    });

document.querySelector("#addItemBtn").addEventListener("click", (e) => {
    e.stopPropagation();
    renderInvoiceItem();
});

document.querySelector("#itemWrapper").addEventListener("click", (e) => {
    if (e.target.className.includes("btn-close")) {
        e.preventDefault();
        e.target.parentElement.parentElement.remove();
    }
});
