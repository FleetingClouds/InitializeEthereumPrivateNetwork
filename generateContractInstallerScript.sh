#!/bin/bash
#
# This script generates an Ξthereum Javascript file from a Solidity Contract
# Supply the title case filename, eg SimpleExample  and the script will
# read SimpleExample.sol, generate a javascript file SimpleExample.js containing
#  - a contract interface : cifSimpleExample
#  - a contract instance  : var simpleExample = cifSimpleExample.new();
#

function usage() {
  echo -e "Usage :  $0 contractFileToInstall contractEntryPoint
    contractFileToInstall - a valid path to an Ξthereum contract file
    contractEntryPoint - the contract entry point

    This script generates the necessary Ξthereum 'web3' javascript code to load
    an Ξthereum contract and report its specifications (address, abi, has, etc.)
    ";
  exit 1;
}

if [[ ! -f ${1} ]]; then usage; fi;
if [[ "X${1}X" == "XX" ]]; then usage; fi;
if [[ $( cat ${1} | grep contract | grep -c ${2}; ) < 1 ]]; then usage; fi;

declare theContractEntryPoint=${2};
declare theContractEntryPointCapitalized=$( echo ${2} | sed -e 's/^./\U&\E/g'  );

declare theContractFileName=$( basename ${1} );
declare theContractPath=$( dirname ${1} );

declare theContractText=$( cat ${1} | sed 's|/\*.*\*/||g' | sed 's/^[ \t]*//;s/[ \t]*$//' | tr '\n' ' ' | tr -s ' ' ); # Strip comments and whitespace

declare theContractInstaller=${theContractPath}/install_${theContractFileName};

declare WORK_DIR=$(  dirname $0  );

# echo "${theContractText}"; 
echo -e "\n ~~ Now creating installer : '${theContractInstaller}' for contract '${theContractEntryPoint}'";

cat << EOCJS > "${theContractInstaller}"
function reportContractInstantiation (e, contract) {
  if(!e) {
    if(!contract.address) {

      console.log("Contract deployment transaction has been sent :");
      console.log("    TransactionHash: " + contract.transactionHash + " waiting to be mined...");
      console.log("You should see a report on its result within the next few minutes.");

    } else {

      console.log("");
      console.log("// Contract mined! Has address: " + contract.address);
      console.log("// Future users will have to execute with these three constants :");
      console.log("var adr${theContractEntryPointCapitalized} = '" + contract.address + "';");
      console.log("var abi${theContractEntryPointCapitalized} = " + JSON.stringify(contract.abi) + ";");
      console.log("");
      console.log("var ${theContractEntryPoint} = eth.contract(abi${theContractEntryPointCapitalized}).at(adr${theContractEntryPointCapitalized});");
      console.log("");
      console.log("// Usage example :");
      console.log("eth.getCode(${theContractEntryPoint}.address);");
      console.log("${theContractEntryPoint}.greet();"); // "
      console.log("");

    }
  }
};


loadScript("${WORK_DIR}/json2.min.js");

admin.setSolc('/usr/bin/solc');
personal.unlockAccount(eth.accounts[0], 'plokplok');

var srcContract = "${theContractText}";

/*
console.log("Contract source code is : ");
console.log(srcContract);
*/

var objContract = web3.eth.compile.solidity(srcContract);

var _message = 'YOU WILL HAVE TO DEFINE THE ARGUMENTS YOURSELF';
console.log("_arguments is : " + _message);

var ${theContractEntryPoint}Contract = web3.eth.contract(objContract.${theContractEntryPoint}.info.abiDefinition);

var ${theContractEntryPoint} = ${theContractEntryPoint}Contract.new (
      _message,
      {
         from: web3.eth.accounts[0], 
         data: objContract.${theContractEntryPoint}.code, 
         gas: 1000000
      },
      reportContractInstantiation
);

/*
var slp = 300;
console.log("Sleeping for " + slp);
admin.sleep(slp);

console.log("${theContractEntryPoint} is : " + ${theContractEntryPoint}.address);

eth.getCode(${theContractEntryPoint}.address);
${theContractEntryPoint}.greet();
*/
EOCJS


