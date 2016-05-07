#!/bin/bash
#
# This script generates an Ethereum Javascript file from a Solidity Contract
# Supply the title case filename, eg SimpleExample  and the script will
# read SimpleExample.sol, generate a javascript file SimpleExample.js containing
#  - a contract interface : cifSimpleExample
#  - a contract instance  : var simpleExample = cifSimpleExample.new();
#

if [[ ! -f $1 ]]; then echo "There is no file $(pwd)/$1"; exit 1; fi;

declare theContract=$1;
echo "Contract in the file '${theContract}'";


cat << EOCJS > /tmp/install_${theContract}.js
function reportContractInstantiation (e, contract) {
  if(!e) {
    if(!contract.address) {
      console.log("Contract transaction send: TransactionHash: " + contract.transactionHash + " waiting to be mined...");

    } else {
      console.log("Contract mined! Has address: " + contract.address);
      console.log("Future users will have to execute with these three instruction :");
      console.log("var abiGreeter = '" + contract.abi + "';");
      console.log("var adrGreeter = '" + contract.address + "';");
      console.log("var greeter = eth.contract(abiGreeter).at(adrGreeter);");
    }
  }
};


admin.setSolc('/usr/bin/solc');
personal.unlockAccount(eth.accounts[0], 'plokplok');

var srcGreeter = 'contract mortal { address owner; function mortal() { owner = msg.sender; } function kill() { if (msg.sender == owner) suicide(owner); } } contract greeter is mortal { string greeting; function greeter(string _greeting) public { greeting = _greeting; } function greet() constant returns (string) { return greeting; } }';
console.log("srcGreeter is : ");
srcGreeter;

var greeterCompiled = web3.eth.compile.solidity(srcGreeter);
console.log("greeterCompiled is : ");
greeterCompiled;

var _greeting = 'Hello Wonderful!';
console.log("_greeting is : " + _greeting);

var greeterContract = web3.eth.contract(greeterCompiled.greeter.info.abiDefinition);
console.log("greeterContract is : ");
greeterContract;

var greeter = greeterContract.new (
      _greeting,
      {
         from:web3.eth.accounts[0], 
         data: greeterCompiled.greeter.code, 
         gas: 1000000
      },
      reportContractInstantiation
);

var slp = 60;
console.log("Sleeping for " + slp);
admin.sleep(slp);

console.log("greeter is : " + greeter.address);


// eth.getCode(greeter.address);
// greeter.greet();
EOCJS

#
cat /tmp/install_${theContract}.js;

