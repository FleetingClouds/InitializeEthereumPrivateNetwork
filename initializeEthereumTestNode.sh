#!/bin/bash

# ############################################################################
#
# This bash script will set up a private Ξthereum test network.
#
# It can do either a "root node" or a "client node".  It will prompt for 
# initial parameters and then do all the rest of the work for you.
#
# Executed in a "client node" it will use SSH and SCP to get 
# initialization files from the "root node".
#
# It is designed and tested on Qemu/KVM virtual machines 
# running Xubuntu Xenial Xerus Desktop.
#
# It should work in most Linux machines.
# Please let me know if you have difficulties.
#
#
# ############################################################################

set -e;
#

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#    DEPENDENCIES
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CURR_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

echo ${CURR_DIR};
source ${CURR_DIR}/utils/utilities.sh

declare MIN_MEM=1200;
if checkSufficientMemory ${MIN_MEM}; then
  echo -e "\n         According to 'free -m' your available memory is 
         less than the viable minimum :: ${MIN_MEM}MB.\n";
  exit 1;
fi;


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#    CONSTANTS
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
CLIENT_NODE_TYPE="CLIENT";
ROOT_NODE_TYPE="ROOT";

USER_VARS_FILE_NAME="${HOME}/.userVars.sh";

source ${CURR_DIR}/utils/manageShellVars.sh
source ${CURR_DIR}/shellVarDefs.sh

declare PRELOAD_SCRIPT_NAME="ROSSutils.js";
declare DEMO_SCRIPT_NAME="rossDemo.js";

declare CONTRACT_INSTALLER_SCRIPT_NAME="generateContractInstallerScript.sh";
declare EXAMPLE_CONTRACT_NAME="Greeter.js";

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  Specify required shell var definitions by group
#
COMMON_PARMS=(
  "NETWORK_ID" \
  "ACCOUNT_PASSWORD" \
  "PROJECT_DIR" \
  );

CLEANER_PARMS=(
  "DROP_DAGS" \
  "DROP_BLOCKCHAIN" \
  "DROP_CLIENTFILES" \
  );

CLIENT_PARMS=(
  "NETWORK_ROOT_IP" \
  "NETWORK_ROOT_UID" \
  "ROOT_PROJECT_DIR" \
  "NODE_INFO_FILE" \
  );


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  askUserForNodeType -- Ask which node type to build and get its parms list.
#
function askUserForNodeType()
{

  CHOICE="";
  NODE_TYPE="";

  loadShellVars;

  if [[ "${NODE_TYPE}" == "${CLIENT_NODE_TYPE}"  ||  "${NODE_TYPE}" == "${ROOT_NODE_TYPE}"  ]]; then

    echo "This node was previously built as a : ${NODE_TYPE}"; 

  else

    while [[ "X${CHOICE}X" == "XX" ]]
    do

      echo -e "\n";

      read -ep "Please choose <r>oot node, <c>lient node or <q>uit. (r/c/q) ::  " -n 1 -r USER_ANSWER

      CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
      if [[ "X${CHOICE}X" == "XqX" ]]; then
        read -ep "Really quit? (y/n)::  " -n 1 -r USER_ANSWER
        CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
        if [[ "X${CHOICE}X" == "XyX" ]]; then echo "Skipping this operation."; exit 1; fi;

      elif [[ "X${CHOICE}X" == "XrX" ]]; then
        read -ep "Get parameters and generate a new ROOT node now? (y/n)::  " -n 1 -r USER_ANSWER
        CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
        if [[ "X${CHOICE}X" == "XyX" ]]; then
          NODE_TYPE=${ROOT_NODE_TYPE};
        fi;

      elif [[ "X${CHOICE}X" == "XcX" ]]; then
        read -ep "Get parameters and generate a new CLIENT node now? (y/n)::  " -n 1 -r USER_ANSWER
        CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
        if [[ "X${CHOICE}X" == "XyX" ]]; then
          NODE_TYPE=${CLIENT_NODE_TYPE};
        fi;

      fi;
      echo "  "
    done;

  fi;


  if [[  "${NODE_TYPE}" == "${CLIENT_NODE_TYPE}"  ]]; then
    echo "Requesting parameters for CLIENT set up.";
    PARM_NAMES=("${COMMON_PARMS[@]}" "${CLIENT_PARMS[@]}" "${CLEANER_PARMS[@]}");

  elif [[  "${NODE_TYPE}" == "${ROOT_NODE_TYPE}"  ]]; then

    echo "Requesting parameters for ROOT set up.";
    PARM_NAMES=("${COMMON_PARMS[@]}" "${CLEANER_PARMS[@]}");

  else

    echo "Unclear if CLIENT or ROOT node is required.";
    exit 1;

  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  installDependencies -- Install Ξthereum and related dependencies.
#      ( change "if" statement to speed up for repeat use )
function installDependencies()
{

  if aptNotYetInstalled "ethereum"; then

    echo " ~~ Installing dependencies . . .";
    sudo apt-get -y install software-properties-common;
    sudo add-apt-repository -y ppa:ethereum/ethereum;
    sudo add-apt-repository -y ppa:ethereum/ethereum-dev;
    sudo apt-get update;
    # # sudo apt-get install -y cpp-ethereum;
    sudo apt-get install -y ethereum;
    sudo apt-get install -y solc;

  else
    echo "Skipped dependency installation 'coz done already.";
  fi

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  prepareWorkingFilesStructure -- Prepare a consistent file layout
#
function prepareWorkingFilesStructure()
{

  echo -e "\n ~~ Preparing work directories in ${WORK_DIR}." ;

  mkdir -p ${WORK_DIR}/geth;
  mkdir -p ${WORK_DIR}/scripts;
  mkdir -p ${HOME}/${EXAMPLES_DIR};

  touch ${WORK_DIR}/prvWhsmn.log;

  if [[ ! -d ~/.ssh ]]; then 
    mkdir -p .ssh;
    chmod 700 .ssh
  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  selectivelyPurgeFilesAsRequested -- Clean up for retry
#
function selectivelyPurgeFilesAsRequested()
{

  if [[ 0 -eq 0 ]]; then

    if [[ ${DROP_DAGS} == "y" ]]; then 
      echo "   ~ Purging DAG files";
      rm -fr ~/.ethash;
    fi;

    if [[ ${DROP_BLOCKCHAIN} == "y" ]]; then 
      echo "   ~ Purging block chain files";
      rm -fr ${WORK_DIR}/geth/chaindata;
    fi;

    if [[ ${DROP_CLIENTFILES} == "y" ]]; then 

      echo "   ~ Purging work files";
      rm -fr ${WORK_DIR}/geth/dapp/;
      rm -fr ${WORK_DIR}/geth/keystore/;
      rm -fr ${WORK_DIR}/geth/history;
      rm -fr ${WORK_DIR}/geth/nodekey;
      rm -fr ${WORK_DIR}/${GENESIS_FILE};
      rm -fr ${WORK_DIR}/geth/static-nodes.json
      
      rm -fr ${WORK_DIR}/prvWhsmn.log;
      rm -fr ${WORK_DIR}/.pwd;
    fi;

  else
    echo "Skipped purging files.";
  fi

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  addUnconfiguredGenesisFile -- Get the unconfigured Genesis file
#
function addUnconfiguredGenesisFile()
{

  echo -e "\n ~~ Copying an unconfigured Genesis file to the workspace";
  cp ./js/${GENESIS_FILE} ${WORK_DIR};

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  recordAccountsPassword -- making this as secure as reasonably possible
#
function recordAccountsPassword()
{

  echo -e "\n ~~ Writing accounts password to ~/.ssh/.EthereumAccountsPassword"
  cat << EOPWD > ~/.ssh/.EthereumAccountsPassword
${ACCOUNT_PASSWORD}
EOPWD

  chmod 700 ~/.ssh/.EthereumAccountsPassword;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  getBaseAccount -- If eth.account[0] exists, get it into a shell variable
#
function getBaseAccount()
{

  echo -e "\n ~~ Try to get base account";
  CB=$(geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} --verbosity 0 --exec eth.accounts[0] console 2> /tmp/err);
  if [[ "$?" -gt "0" ]]; then
    CB=$(geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} --verbosity 0 --exec eth.accounts[0] attach ipc:/${WORK_DIR}/geth/geth.ipc 2> /tmp/err);
  fi;

#    echo -e "\n$(</tmp/err).";
#    echo -e "      Is geth running already?  Quitting . . . ";
#    exit 1;
#
#  else

    COINBASE=$(sed 's/^"\(.*\)"$/\1/' <<< ${CB});
    # echo "Checking : ${COINBASE} )" ;
    if [[ ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then
      echo "( Coin base account found : ${COINBASE} )" ;
    else
      echo "( No coin base account found. )" ;
      COINBASE="";
    fi;

#  fi;


};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  getBaseAccountBalance -- If eth.account[0] exists, get it into a shell variable
#
function getBaseAccountBalance()
{

  echo -e "\n ~~ Try to read base account balance";
  if [[ ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then
    echo "   ~ Getting balance of base account : ${COINBASE} )" ;
    BALANCE=$(geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} --verbosity 0 --exec 'web3.fromWei(eth.getBalance(eth.accounts[0]), "ether")' console 2> /tmp/err);
    if [[ "$?" -gt "0" ]]; then
      BALANCE=$(geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} --verbosity 0 --exec 'web3.fromWei(eth.getBalance(eth.accounts[0]), "ether")' attach ipc:/${WORK_DIR}/geth/geth.ipc 2> /tmp/err);
    fi;
    echo "   ~ Current coin base balance : ${BALANCE} Eth";
  else
    echo "Found no coin base account." ;
    exit 1;
  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  makeInitialCoinBaseAccount -- create the account to write into the Genesis file
#
function makeInitialCoinBaseAccount()
{

  if [[ ! ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then

    echo " ~~ Preparing initial coin base account " ;
    declare ACCT=$(geth  --datadir "${WORK_DIR}/geth" --verbosity 0  --password ~/.ssh/.EthereumAccountsPassword account new);
    # echo Account = ${ACCT};
    declare ACCT_NO=$(echo ${ACCT}  | cut -d "{" -f 2 | cut -d "}" -f 1); 
    # echo Account number = ${ACCT_NO};
    COINBASE="0x${ACCT_NO}";
    echo "( Coin base account set to : ${COINBASE} )" ;

  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  configureGenesisFile -- Add coin base account preallocation to Genesis file.
#
function configureGenesisFile()
{

  declare ALLOC="\"${COINBASE}\": { \"balance\": \"20000000000000000000\" }";
  # echo Alloc = ${ALLOC};

  echo -e "\n ~~ Update the Genesis file with preallocation to coin base account." ;
  sed -i -e "s/\"alloc\": {}/\"alloc\": { ${ALLOC} }/g" ${WORK_DIR}/${GENESIS_FILE};

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  initializeBlockChain -- builds the blockchain from the genesis block
#
function initializeBlockChain()
{

  echo -e "\n ~~ Initialize the Block Chain's foundation block" ;
  geth --datadir "${WORK_DIR}/geth" init ${WORK_DIR}/${GENESIS_FILE}

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createDAGfileIfNotYetDone -- Builds the Dagger-Quasimodo file, if not exists
#
function createDAGfileIfNotYetDone()
{

  if [ ! -f ~/.ethash/full-R23-0000000000000000 ]; then  
    echo -e "\n ~~ Creating DAG file.";
    mkdir -p ~/.ethash;
    geth  --datadir "${WORK_DIR}/geth" --verbosity 3  makedag 0 ~/.ethash; 
  fi;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  addSimpleMiningScript -- JavaScript to get the first few fake ether to work with
#
function addSimpleMiningScript()
{

  echo -e "\n ~~ copy mining initialization script to workspace. " ;
  cp ./js/${MINING_SCRIPT} ${WORK_DIR}/scripts;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createKeyPairForSSH -- Confirm user really wants us to mess with their SSH settings.
#
function createKeyPairForSSH()
{

  echo -e "   ~ Found no SSH keys! " ;
  read -ep "   - Will create an SSH key pair without password. Accept? (y/q) ::  " -n 1 -r USER_ANSWER;
  CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
  if [[ "X${CHOICE}X" == "XyX" ]]; then
    echo "Creating key pair . . . ";
    mkdir -p ~/.ssh;
    ssh-keygen -N "" -f ~/.ssh/id_rsa;
  else
    echo "Quitting . . . ";
    exit 1;
  fi;


};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  getRootNodeOperationsFiles -- RPC over SSH to pull initial configuration
#
function getRootNodeOperationsFiles()
{

  echo -e "\n ~~ Collecting initial configuration from root node. " ;

#  rm -fr .ssh;           

  if $(ssh -q -o "BatchMode=yes" ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP} "echo 2>&1"); then

    echo "Root node ${NETWORK_ROOT_IP} connection tested : OK";

  else

    if [[ ! -f ${HOME}/.ssh/id_rsa  ]]; then
      createKeyPairForSSH;
    fi;

    echo "   ~ Passing public key to root node ${NETWORK_ROOT_IP}.  Please enter your password when prompted.";
    ssh-copy-id ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP};
    ssh-add;

    if $(ssh -q -o "BatchMode=yes" ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP} "echo 2>&1"); then

      echo -e "\n Root node ${NETWORK_ROOT_IP} connection tested : OK";

    else

      echo -e "\n SSH connection failing. Can't continue.";
      exit 1;

    fi;

  fi;

  echo -e "\n ~~  RPC to bundle initialization files.";
  ssh ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP} ${ROOT_PROJECT_DIR}/collectInitializationPackage.sh;

  echo -e "\n ~~  SCP to pull over the initialization files bundle.";
  scp -q ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP}:/tmp/initialFiles.tar.gz /tmp;

  echo -e "\n ~~  Decompress initialization files bundle.";
  rm -fr ${WORK_DIR}/geth/chaindata
  tar --gunzip --extract --file /tmp/initialFiles.tar.gz --directory ${WORK_DIR};

  echo -e "\n ~~  SCP to pull over the DAG file, if necessary.";
  if [[ -f ~/.ethash/full-R23-0000000000000000 ]]; then
    echo "(  Have DAG already.)"; 
  else
    scp -qr ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP}:/home/${NETWORK_ROOT_UID}/.ethash ${HOME};
  fi;

  echo -e "\n ~~  RPC to get root node base account.";
  
  declare ROOT_GETH_PATH=/home/${NETWORK_ROOT_UID}/${ROOT_PROJECT_DIR}/geth;
  declare IPC_ENDPOINT=${ROOT_GETH_PATH}/geth.ipc;
  
  declare GETH_CONSOLE_RUNNING=$(ssh ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP} "ps aux | grep -v grep | grep geth | grep -c console");
  declare GETH_CONNECTION_TYPE="console";

  if [[  ${GETH_CONSOLE_RUNNING} -gt 0  ]]; then GETH_CONNECTION_TYPE="attach"; fi;


  PEER_ACCT=$(ssh ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP} geth \
    --verbosity 0 \
    --datadir \"${ROOT_GETH_PATH}\" \
    --networkid ${NETWORK_ID} \
    --exec \"eth.accounts[0]\" \
  ${GETH_CONNECTION_TYPE}  \"ipc:/${IPC_ENDPOINT}\");
  
  echo "Peer account : ${PEER_ACCT}";

  echo -e "(  Root node files have been acquired.  )";



  declare LISTEN_PORT=$(cat ${WORK_DIR}/${NODE_INFO_FILE} | grep "listener:" | sed 's/ //g' | cut -d : -f 2);
  declare NODE_ID=$(    cat ${WORK_DIR}/${NODE_INFO_FILE} | grep "id:" | cut -d \" -f 2);
  # echo -e " Port : ${LISTEN_PORT}.  Node : ${NODE_ID}.  ";

  ENODE_SPEC="enode://${NODE_ID}@${NETWORK_ROOT_IP}:${LISTEN_PORT}?discport=0";
  echo -e " ~~ Writing Enode Spec (${ENODE_SPEC}) 
                     to the file ${WORK_DIR}/geth/static-nodes.json.";

  cat << EOSNJ > ${WORK_DIR}/geth/static-nodes.json
[
  "${ENODE_SPEC}"
]
EOSNJ

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createSimpleTransactionExample -- A transaction embedding the Acct # of the root node
#
function createSimpleTransactionExample()
{

  cat << EOSTE > ${WORK_DIR}/scripts/simpleTransactionExample.js

primary = eth.accounts[0];
primary_balance = web3.fromWei(eth.getBalance(primary), "ether");


personal.newAccount('${ACCOUNT_PASSWORD}');
secondary = eth.accounts[0];
secondary_balance = web3.fromWei(eth.getBalance(secondary), "ether");

personal.unlockAccount(primary, "${ACCOUNT_PASSWORD}");
eth.sendTransaction({from: primary, to: secondary, value: web3.toWei(3.3, "ether")})

miner.start(2); admin.sleepBlocks(1); miner.stop();
web3.fromWei(eth.getBalance(secondary), "ether"); // ought to be 3.3

remote_account=${PEER_ACCT};

personal.unlockAccount(secondary, '${ACCOUNT_PASSWORD}');
eth.sendTransaction({from: secondary, to: remote_account, value: web3.toWei(2.2, "ether")})

miner.start(2); admin.sleepBlocks(1); miner.stop();
web3.fromWei(eth.getBalance(secondary), "ether"); // ought to be 1.00333

EOSTE

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  mineSomeBlocksIfLowBalance -- Execute mining script if no Ether mined yet 
#
function mineSomeBlocksIfLowBalance()
{
  declare MINBAL=10;
  echo -e "\n ~~ Mine a few blocks if Eth balance ${BALANCE%.*} is less than ${MINBAL}. " ;
  if [[ ${BALANCE%.*} -lt ${MINBAL} ]]; then

    echo -e "\n ~~ Executing mining initialization script for first three blocks. " ;
    echo "     You can monitor mining progress with : ";
    echo "          tail -fn 500 ${WORK_DIR}/prvWhsmn.log";
    geth \
        --datadir "${WORK_DIR}/geth" \
        --verbosity 4 \
        --maxpeers "5" \
        --networkid ${NETWORK_ID} \
        --nodiscover \
      js ${WORK_DIR}/scripts/${MINING_SCRIPT} \
              2>> ${WORK_DIR}/prvWhsmn.log

  else
    echo "   ~ Skipped mining first blocks 'coz balance is ${BALANCE}.";
  fi

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createTransactionMonitoringExample -- Get the unconfigured Genesis file
#
function createTransactionMonitoringExample()
{

  echo -e "\n ~~ Copying a JavaScript example of transaction monitoring.";
  cp ./js/${MONITORING_EXAMPLE} ${WORK_DIR}/scripts;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createRunOnSaveScriptExample -- Get the unconfigured Genesis file
#
function createRunOnSaveScriptExample()
{

  echo -e "\n ~~ Copying an example of Run-On-Save-Script (ROSS) usage to '${WORK_DIR}/scripts'.";
  cp ${CURR_DIR}/js/RunOnSaveScript/${PRELOAD_SCRIPT_NAME} ${WORK_DIR}/scripts;
  cp ${CURR_DIR}/js/RunOnSaveScript/${DEMO_SCRIPT_NAME} ${HOME}/${EXAMPLES_DIR};
  sed -i s/ROOT_PRIMARY_ACCOUNT/${PEER_ACCT}/ ${HOME}/${EXAMPLES_DIR}/${DEMO_SCRIPT_NAME};

  cat << EOPPJS > ${HOME}/.ssh/pwdPrimary.js
function pwdPrimary(){
  return "${ACCOUNT_PASSWORD}";
}
EOPPJS

};


function copyContractInstallerExampleScripts()
{

  echo -e "\n ~~ Copying a contract installer script '${CONTRACT_INSTALLER_SCRIPT_NAME}' to '${WORK_DIR}/scripts' and . . .";
  cp ${CURR_DIR}/${CONTRACT_INSTALLER_SCRIPT_NAME} ${WORK_DIR}/scripts;

  echo -e "  . . . copying a sample contract '${EXAMPLE_CONTRACT_NAME}' for installation to '${HOME}/${EXAMPLES_DIR}'.";
  cp ${CURR_DIR}/js/GreeterContract/${EXAMPLE_CONTRACT_NAME} ${HOME}/${EXAMPLES_DIR};

};


function addScriptAliasNamesToUserProfile()
{

  declare START_UP_FILE=${HOME}/.profile;

  declare START_EXPLANATION="### Begin Ξthereum Dev Script additions. From https://github.com/FleetingClouds/InitializeEthereumPrivateNetwork";
  declare END_EXPLANATION="### End Ξthereum Dev Script additions.";

  declare aliasRoss="cmdROSS()";
  declare aliasAutoGeth="cmdGeth()";
#  declare aliasInstCtrt="alias instCtrt" ;

  declare newAliasRoss="${aliasRoss} { ${CURR_DIR}/utils/run_on_save.sh \$*; }; export -f cmdROSS;";
  declare newAliasAutoGeth="${aliasAutoGeth} { geth --datadir ${WORK_DIR}/geth --jspath ${WORK_DIR}/scripts --preload '${PRELOAD_SCRIPT_NAME}' --exec 'currentTask()' --networkid ${NETWORK_ID} attach ipc:/${WORK_DIR}/geth/geth.ipc; }; export -f cmdGeth;";
#  declare newAliasInstCtrt="${aliasInstCtrt}=\"${CURR_DIR}/utils/installContract.sh\";";

  echo -e "\n ~~ Adding script alias names to user profile (${START_UP_FILE}).";

  if [[ $(cat ${START_UP_FILE} | grep -c "${START_EXPLANATION}") -lt 1 ]]; then
    echo ${START_EXPLANATION} >> ${START_UP_FILE};
  fi;

  if [[ $(cat ${START_UP_FILE} | grep -c "${aliasRoss}") -gt 0 ]]; then
    if [[ $(cat ${START_UP_FILE} | grep -c "${newAliasRoss}") -lt 1 ]]; then
      sed -i "/${aliasRoss}/c${newAliasRoss}" ${START_UP_FILE};
    fi;
  else
    echo ${newAliasRoss} >> ${START_UP_FILE};
  fi;

  if [[ $(cat ${START_UP_FILE} | grep -c "${aliasAutoGeth}") -gt 0 ]]; then
    # echo "Looking for ${newAliasAutoGeth}";
    if [[ $(cat ${START_UP_FILE} | grep -c "${newAliasAutoGeth}") -lt 1 ]]; then
      sed -i "/${aliasAutoGeth}/c${newAliasAutoGeth}" ${START_UP_FILE};
    fi;
  else
    echo ${newAliasAutoGeth} >> ${START_UP_FILE};
  fi;

#  if [[ $(cat ${START_UP_FILE} | grep -c "${aliasInstCtrt}") -gt 0 ]]; then
#    if [[ $(cat ${START_UP_FILE} | grep -c "${newAliasInstCtrt}") -lt 1 ]]; then
#      sed -i "/${aliasInstCtrt}/c${newAliasInstCtrt}" ${START_UP_FILE};
#    fi;
#  else
#    echo ${newAliasInstCtrt} >> ${START_UP_FILE};
#  fi;

  if [[ $(cat ${START_UP_FILE} | grep -c "${END_EXPLANATION}") -lt 1 ]]; then
    echo ${END_EXPLANATION} >> ${START_UP_FILE};
    echo "" >> ${START_UP_FILE};
  fi;


};


function provideJsonUsageToWeb3()
{

  wget -P ${WORK_DIR}/scripts/ http://cdnjs.cloudflare.com/ajax/libs/json2/20121008/json2.min.js


}

# ############################################################################
#
#        This is where all the work starts
#
# ############################################################################


echo -e "\n\n";
echo -e "This 'wizard' makes it easy to set up an Ξthereum private network between virtual machines";
echo -e "It's intended as a quick start for developer experimentation";

loadShellVars;

askUserForNodeType;
if [[ "${NODE_TYPE}" == "${CLIENT_NODE_TYPE}"  ||  "${NODE_TYPE}" == "${ROOT_NODE_TYPE}"  ]]; then

  # echo ${PARM_NAMES[@]};
  askUserForParameters PARM_NAMES[@];
  declare WORK_DIR="${HOME}/${PROJECT_DIR}";

  installDependencies;

  declare EXAMPLES_DIR="projects/examples";
  prepareWorkingFilesStructure;

  declare GENESIS_FILE="Genesis.json";
  selectivelyPurgeFilesAsRequested;

  recordAccountsPassword;

  declare COINBASE="";
  getBaseAccount;
  makeInitialCoinBaseAccount;

  if [[  "${NODE_TYPE}" == "${ROOT_NODE_TYPE}" ]]; then

    addUnconfiguredGenesisFile;

    configureGenesisFile;

    initializeBlockChain;

    createDAGfileIfNotYetDone;

  elif [[ ! -d ~/.ethash || ! -d ${WORK_DIR}/geth/static-nodes.json ]]; then

    declare ENODE_SPEC="";
    declare PEER_ACCT="";
    getRootNodeOperationsFiles;

  else
    echo "------------------------";
  fi;

  declare MINING_SCRIPT="initialTrivialMiningScript.js";
  addSimpleMiningScript;

  declare BALANCE=0;
  getBaseAccountBalance;

  mineSomeBlocksIfLowBalance;

  echo "";
  echo "";
  echo -e "\n      * * * Setup has Finished * * *  ";
  echo -e "\n You are ready to start mining. Run the following command : ";
  echo "";
  echo geth --datadir "${WORK_DIR}/geth" --verbosity 3 --maxpeers "5" --networkid ${NETWORK_ID} --nodiscover console 2\>\> ${WORK_DIR}/prvWhsmn.log
  echo "";
  echo -e "\n ~~ To view accumulated ether, enter      > web3.fromWei(eth.getBalance(eth.accounts[0]), \"ether\") ";
  echo -e "\n ~~ To continue mining                    > miner.start(2) ";
  echo -e "\n ~~ Then to pause mining                  > miner.stop() ";

  if [[ "${NODE_TYPE}" == "${ROOT_NODE_TYPE}" ]]; then

    declare MONITORING_EXAMPLE="MineIfWorkToBeDone.js";
    createTransactionMonitoringExample;
    echo -e "\n ~~ To have your root node process transactions automatically run it with this command . . .";
    echo geth --datadir "${WORK_DIR}/geth" --jspath "${WORK_DIR}/scripts" --preload \"${MONITORING_EXAMPLE}\" --verbosity 3 --maxpeers 5 --networkid ${NETWORK_ID} --nodiscover console 2\>\> ${WORK_DIR}/prvWhsmn.log
    echo -e "    When there are transactions in need of processing you will see . . .  ";
    echo -e "     * ==  Pending transactions! Mining...  == *    ";
    echo -e "  . . . and once all transactions have been processed it will report . . .    ";
    echo -e "     * ==  No transactions! Mining stopped.  == *   ";    

  else

    createSimpleTransactionExample;
    echo -e "\n ~~ To pay to the root node's base acct use these two commands.";
    echo -e "        > personal.unlockAccount(eth.accounts[0], '${ACCOUNT_PASSWORD}');";
    echo -e "        > eth.sendTransaction({from: eth.accounts[0], to: ${PEER_ACCT}, value: web3.toWei(1, \"ether\")})";


    addScriptAliasNamesToUserProfile;
    createRunOnSaveScriptExample;
    echo -e "\n ~~ To test scripts and contracts each time you save editor changes (ross) try this : ";
    echo -e "    $(whoami)@$(hostname):~$ source ~/.profile";
    echo -e "    $(whoami)@$(hostname):~$ cd ${HOME}/${EXAMPLES_DIR}";
    echo -e "    $(whoami)@$(hostname):~/${EXAMPLES_DIR}$ cmdROSS rossDemo.js cmdGeth";

    copyContractInstallerExampleScripts;
    echo -e "\n ~~ To easily install a contract try this : ";
    echo -e "    $(whoami)@$(hostname):~$ source ~/.profile";
    echo -e "    $(whoami)@$(hostname):~$ cd ${HOME}/${EXAMPLES_DIR}";
    echo -e "    $(whoami)@$(hostname):~/${EXAMPLES_DIR}$ cmdROSS rossDemo.js cmdGeth";

  fi;  

  echo -e "\n ~~ To attach from another local terminal session, use :";
  echo geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} attach ipc:/${WORK_DIR}/geth/geth.ipc
  echo "";
  echo "";

  if [[ "${NODE_TYPE}" == "${ROOT_NODE_TYPE}" ]]; then

    cp ./utils/collectInitializationPackage.sh ${WORK_DIR};
    chmod a+x ${WORK_DIR}/collectInitializationPackage.sh;

    echo -e "\n ~~ Client nodes will need these four data elements in order to connect :";
    echo -e "    ~ The IP address of your root node machine                      :: ${LOCAL_IP_ADDR}";
    echo -e "    ~ The directory for geth's working files ON THE ROOT NODE       :: ${PROJECT_DIR}";
    echo -e "    ~ The Ξthereum network ID                                       :: ${NETWORK_ID}";
    echo -e "    ~ The SSH user name of the root node machine's Ξthereum account :: ${USER}";
    echo -e "    ~ The SSH password of the root node machine's Ξthereum account  :: ????????????";

  fi;

  echo "";
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";

  echo "Done.";
  exit 0;

else
  echo "NODE_TYPE is confused.  Can only be CLIENT or ROOT. Quitting."
  exit 1;
fi;


