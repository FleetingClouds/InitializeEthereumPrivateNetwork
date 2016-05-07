#!/bin/bash
#
# This script generates an Ethereum Javascript file from a Solidity Contract
# Supply the title case filename, eg SimpleExample  and the script will
# read SimpleExample.sol, generate a javascript file SimpleExample.js containing
#  - a contract interface : cifSimpleExample
#  - a contract instance  : var simpleExample = cifSimpleExample.new();
#

if [[ ! -f $1 ]]; then echo "There is no file $(pwd)/$1"; exit 1; fi;

declare cntCtrcts=$(cat $1 | grep -c "^contract");
echo "contract called '${possiblename}' in the file '$1'";
exit;

if (( ${cntCtrcts} > 1 )); then 
  declare possiblename=$(echo $1 | cut -d '.' -f 1)
  declare theContract=$(cat $1 | egrep "^contract" | grep "${possiblename}" | cut -d ' ' -f 2);
  if [[ "X${theContract}X" == "XX" ]]; then echo "There no is contract called '${possiblename}' in the file '$1'"; exit 1; fi;
else
  declare theContract=$(cat $1 | egrep "^contract" | cut -d ' ' -f 2);
fi;


declare lcContract=$(echo "${theContract}" | tr '[:upper:]' '[:lower:]');

declare gasMax=$2;
if [[ ! ${gasMax} =~ ^-?[0-9]+$ ]]; then gasMax=1000000; fi;

echo "Building the contract,'${theContract}' with gas limit ${gasMax}.";

declare jsonContracts=$(solc --optimize  --combined-json abi,bin ${theContract}.sol);
declare tmp=$(echo ${jsonContracts} | jq ".contracts.${theContract}.abi"); tmp="${tmp%\"}"; tmp="${tmp#\"}";
declare abiContract=$(echo ${tmp} | sed  -e 's|\\\"|\"|g' | sed  -e 's|\\n||g');

declare tmp=$(echo ${jsonContracts} | jq ".contracts.${theContract}.bin"); tmp="${tmp%\"}"; tmp="${tmp#\"}";
declare binContract=$(echo ${tmp} | sed  -e 's|\\\"|\"|g' | sed  -e 's|\\n||g');

cat << EOCJS > /tmp/${theContract}.sol.js
var ${theContract}Compiled = {
  ${theContract}: {
    code: "${binContract}",
    info: {
      abiDefinition: ${abiContract}
    }
  }
  
var cif${theContract} = web3.eth.contract(${abiContract});
var ${lcContract} = cif${theContract}.new(
   {
     from: web3.eth.accounts[0], 
     data: greeterCompiled.greeter.code, 
     gas: ${gasMax}
   }, function(e, contract){
    console.log(e, contract);
    if (typeof contract.address != 'undefined') {
         console.log('Contract mined! address: ' + contract.address + ' transactionHash: ' + contract.transactionHash);
    }
 })
 
 
EOCJS


#
cat /tmp/${theContract}.sol.js;






