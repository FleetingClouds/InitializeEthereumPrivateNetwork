#!/bin/bash

# ############################################################################
#
# This bash script will set up a private Ethereum test network.
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
#    CONSTANTS
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CLIENT_NODE_TYPE="CLIENT";
ROOT_NODE_TYPE="ROOT";


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#    Utility Functions
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

USER_VARS_FILE_NAME="${HOME}/.userVars.sh";

declare -A SHELLVARS;
declare SHELLVARNAMES=();

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  addShellVar -- add a definition to the list of required shell variables
#
function addShellVar() {

  declare -A SHELLVAR;

  SHELLVARNAMES+=($1);
  SHELLVAR['LONG']=$2;
  SHELLVAR['SHORT']=$3;
  SHELLVAR['VAL']=$4;
  for key in "${!SHELLVAR[@]}"; do
    SHELLVARS[$1,$key]=${SHELLVAR[$key]}
  done

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  Build shell variables definitions
#
# PREPARE ALL NEEDED SHELL VARIABLES BELOW THIS LINE
# EXAMPLE
# addShellVar 'NAME' \
#             'LONG' \
#             'SHORT' \
#             'VAL';


addShellVar 'NETWORK_ID' \
            'The number you will use to identify your network :: ' \
            'Network Identification number (--networkid) : ${NETWORK_ID} ' \
            '1';

addShellVar 'ACCOUNT_PASSWORD' \
            'The password to use when creating accounts :: ' \
            'Accounts password : ${ACCOUNT_PASSWORD} ' \
            '2';

addShellVar 'NETWORK_ROOT_IP' \
            'The IP address of your root node machine :: ' \
            'Root node IP address : ${NETWORK_ROOT_IP} ' \
            '3';

addShellVar 'NETWORK_ROOT_UID' \
            "The SSH user name of the root node machine's Ethereum account :: " \
            'SSH user id of root node : ${NETWORK_ROOT_UID} ' \
            '4';

addShellVar 'DUMMY' \
            " :: " \
            ' : ${DUMMY} ' \
            '5';


addShellVar 'ROOT_PROJECT_DIR' \
            "The directory for geth's working files ON THE ROOT NODE :: " \
            'Project directory on root node : ${ROOT_PROJECT_DIR}' \
            '6';


addShellVar 'PROJECT_DIR' \
            "The directory for geth's working files on THIS node :: " \
            'Project directory on THIS node : ${PROJECT_DIR} ' \
            '7';


addShellVar 'NODE_INFO_FILE' \
            'Name of the file for the "nodeInfo" of the root node :: ' \
            'Name of nodeInfo file : ${NODE_INFO_FILE} ' \
            '8';


addShellVar 'DROP_DAGS' \
            'You want to delete the DAG file (y/n) :: ' \
            'Delete DAG file (y/n) : ${DROP_DAGS} ' \
            '9';


addShellVar 'DROP_BLOCKCHAIN' \
            'You want to delete the block chain file (y/n) :: ' \
            'Delete block chain (y/n) : ${DROP_BLOCKCHAIN}' \
            '10';


addShellVar 'DROP_CLIENTFILES' \
            'You want to delete all the other client files (y/n) :: ' \
            'Delete other client files (y/n) : ${DROP_CLIENTFILES}' \
            '11';

addShellVar 'NODE_TYPE' \
            '' \
            '' \
            '12';


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  loadShellVars -- get shell variables from file, if exists
#
function loadShellVars() {

  if [ -f ${USER_VARS_FILE_NAME} ]; then
    source ${USER_VARS_FILE_NAME}
  else

    for varkey in "${!SHELLVARNAMES[@]}"; do
      X=${SHELLVARNAMES[$varkey]};
      SHELLVARS["${X},VAL"]=${!X};
      eval "export ${SHELLVARNAMES[$varkey]}='${SHELLVARS[${SHELLVARNAMES[$varkey]},VAL]}'";
    done

  fi

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  saveShellVars -- record shell variables to file
#
function saveShellVars()
{

  echo -e "Saving shell variables to $1";
  echo -e "#/bin/bash\n#  You can edit this, but it may be altered progrmmatically." > $1;
  for varkey in "${!SHELLVARNAMES[@]}"; do
    X=${SHELLVARNAMES[$varkey]};
    eval "echo \"export ${X}='${!X}';\"  >> $1;";
  done

  chown ${SUDOUSER}:${SUDOUSER} ${USER_VARS_FILE_NAME};

}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  askUserForParameters -- iterate a list of shell vars, prompting for setting
#
function askUserForParameters()
{

  declare -a VARS_TO_UPDATE=("${!1}");

  CHOICE="n";
  while [[ ! "X${CHOICE}X" == "XyX" ]]
  do
    ii=1;
    for varkey in "${VARS_TO_UPDATE[@]}"; do
      eval  "printf \"\n%+5s  %s\" $ii \"${SHELLVARS[${varkey},SHORT]}\"";
#      eval   "echo $ii/. -- ${SHELLVARS[${varkey},SHORT]}";
      ((ii++));
    done;

    echo -e "\n\n";

    read -ep "Is this correct? (y/n/q) ::  " -n 1 -r USER_ANSWER
#    USER_ANSWER='q';
    CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
    if [[ "X${CHOICE}X" == "XqX" ]]; then
      echo "Skipping this operation."; exit 1;
    elif [[ ! "X${CHOICE}X" == "XyX" ]]; then

      for varkey in "${VARS_TO_UPDATE[@]}"; do
        read -p "${SHELLVARS[${varkey},LONG]}" -e -i "${!varkey}" INPUT
        if [ ! "X${INPUT}X" == "XX" ]; then eval "${varkey}=\"${INPUT}\""; fi;
      done;

    fi;
    echo "  "
  done;

  saveShellVars ${USER_VARS_FILE_NAME};
  return;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  aptNotYetInstalled -- check if installation is needed
#
function aptNotYetInstalled() {

  set +e;
  return $(dpkg-query -W --showformat='${Status}\n' $1 2>/dev/null | grep -c "install ok installed");
  set -e;

}


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

# echo ${COMMON_PARMS[@]};
# echo ${CLEANER_PARMS[@]};
# echo ${CLIENT_PARMS[@]};

declare LOCAL_IP_ADDR=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1');

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#      Problem domain functions
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  askUserForNodeType -- Ask which node type to build and get its parms list.
#
function askUserForNodeType()
{

  CHOICE="";
  NODE_TYPE="";

  source ${USER_VARS_FILE_NAME};
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
#  installDependencies -- Install Ethereum and related dependencies.
#      ( change "if" statement to speed up for repeat use )
function installDependencies()
{

  if aptNotYetInstalled "ethereum"; then

    sudo apt-get -y install software-properties-common wget;
    # # sudo add-apt-repository -y ppa:ethereum/ethereum;
    sudo add-apt-repository -y ppa:ethereum/ethereum-dev;
    sudo apt-get update;
    # # sudo apt-get install -y cpp-ethereum;
    sudo apt-get install -y ethereum;

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
#  touch ${WORK_DIR}/geth/history;
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
      rm -fr ${WORK_DIR}/Genesis.json;
      
      rm -fr ${WORK_DIR}/prvWhsmn.log;
      rm -fr ${WORK_DIR}/.pwd;
    fi;


  else
    echo "Skipped purging files.";
  fi

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  getUnconfiguredGenesisFile -- Get the unconfigured Genesis file
#
function getUnconfiguredGenesisFile()
{

  echo -e "\n ~~ Get the unconfigured Genesis file"

  declare ORGANIZATION="martinhbramwell";
  declare GIST_UUID="18b80f8e1aef23e692246fa20d256a9f";
  wget -nv -O ${WORK_DIR}/${GENESIS_FILE} https://gist.githubusercontent.com/${ORGANIZATION}/${GIST_UUID}/raw/${GENESIS_FILE};

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
  CB=$(geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} --verbosity 0 --exec eth.accounts[0] console);
  COINBASE=$(sed 's/^"\(.*\)"$/\1/' <<< ${CB});
  # echo "Checking : ${COINBASE} )" ;
  if [[ ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then
    echo "( Coin base account found : ${COINBASE} )" ;
  else
    echo "( No coin base account found. )" ;
    COINBASE="";
  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  getBaseAccountBalance -- If eth.account[0] exists, get it into a shell variable
#
function getBaseAccountBalance()
{

  echo -e "\n ~~ Try to read base account balance";
  if [[ ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then
    echo "   ~ Getting balance of base account : ${COINBASE} )" ;
    BALANCE=$(geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} --verbosity 0 --exec 'web3.fromWei(eth.getBalance(eth.accounts[0]), "ether")' console);
    echo "   ~ Current coin base balance : ${BALANCE} Eth";
  else
    echo "Found no coin base account." ;
    exit 1;
  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
  geth --datadir "${WORK_DIR}/geth" init ${WORK_DIR}/Genesis.json

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createDAGfile -- Builds the Dagger-Quasimodo file, if not exists
#
function createDAGfile()
{

  if [ ! -f ~/.ethash/full-R23-0000000000000000 ]; then  
    echo -e "\n ~~ Creating DAG file.";
    mkdir -p ~/.ethash;
    geth  --datadir "${WORK_DIR}/geth" --verbosity 3  makedag 0 ~/.ethash; 
  fi;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  obtainSimpleMiningScript -- JavaScript to get the first few fake ether to work with
#
function obtainSimpleMiningScript()
{

  echo -e "\n ~~ Obtain mining initialization script. " ;
  declare ORGANIZATION="martinhbramwell";
  declare GIST_UUID="e03cb203b36a9d1523a73c7fd0409e3e";
  wget -nv -O ${WORK_DIR}/${MINING_SCRIPT} https://gist.githubusercontent.com/${ORGANIZATION}/${GIST_UUID}/raw/${MINING_SCRIPT};

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

    if [[ ! -f .ssh/id_rsa  ]]; then
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

  echo -e "\n ~~  SCP to pull over the DAG file.";
  # scp -qr ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP}:/home/${NETWORK_ROOT_UID}/.ethash ${HOME};

  echo -e "\n ~~  RPC to get root node base account.";


  PEER_ACCT=$(ssh ${NETWORK_ROOT_UID}@${NETWORK_ROOT_IP} geth \
    --verbosity 0 \
    --datadir "${ROOT_PROJECT_DIR}/geth" \
    --networkid ${NETWORK_ID} \
    --exec \"eth.accounts[0]\" \
  console);

  echo "Peer account : ${PEER_ACCT}";

  echo -e " (Root node files have been acquired)";



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

  cat << EOSTE > ${WORK_DIR}/simpleTransactionExample.js

primary = eth.accounts[0];
primary_balance = web3.fromWei(eth.getBalance(primary), "ether");


personal.newAccount('plokplok');
secondary = eth.accounts[0];
secondary_balance = web3.fromWei(eth.getBalance(secondary), "ether");

personal.unlockAccount(primary, "plokplok");
eth.sendTransaction({from: primary, to: secondary, value: web3.toWei(3.3, "ether")})

miner.start(2); admin.sleepBlocks(1); miner.stop();
web3.fromWei(eth.getBalance(secondary), "ether"); // ought to be 3.3

remote_account=${PEER_ACCT};

personal.unlockAccount(secondary, 'plokplok');
eth.sendTransaction({from: secondary, to: remote_account, value: web3.toWei(2.2, "ether")})

miner.start(2); admin.sleepBlocks(1); miner.stop();
web3.fromWei(eth.getBalance(secondary), "ether"); // ought to be 1.00333

EOSTE

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  mineFirstBlocksIfZeroBalance -- Execute mining script if no Ether mined yet 
#
function mineFirstBlocksIfZeroBalance()
{

  echo -e "\n ~~ Mine a few blocks if Eth balance too low. " ;
  if [[ ${BALANCE%.*} -lt 1 ]]; then

    echo -e "\n ~~ Executing mining initialization script for first three blocks. " ;
    echo "     You can monitor mining progress with : ";
    echo "          tail -fn 500 ${WORK_DIR}/prvWhsmn.log";
    geth \
        --datadir "${WORK_DIR}/geth" \
        --verbosity 3 \
        --maxpeers "5" \
        --networkid ${NETWORK_ID} \
        --nodiscover \
      js ${WORK_DIR}/${MINING_SCRIPT} \
              2>> ${WORK_DIR}/prvWhsmn.log

  else
    echo "   ~ Skipped mining first blocks 'coz balance is ${BALANCE}.";
  fi


};


# ############################################################################
#
#       This is where all the work starts
#
# ############################################################################

echo -e "\n\n";
echo -e "This 'wizard' makes it easy to set up an Etheruem private network between virtual machines";
echo -e "It's intended as a quick start for developer experimentation";


loadShellVars;

askUserForNodeType;
if [[ "${NODE_TYPE}" == "${CLIENT_NODE_TYPE}"  ||  "${NODE_TYPE}" == "${ROOT_NODE_TYPE}"  ]]; then

  # echo ${PARM_NAMES[@]};
  askUserForParameters PARM_NAMES[@];
  declare WORK_DIR="${HOME}/${PROJECT_DIR}";

  installDependencies;

  prepareWorkingFilesStructure;

  selectivelyPurgeFilesAsRequested;

  recordAccountsPassword;

  declare COINBASE="";
  getBaseAccount;
  makeInitialCoinBaseAccount;

  declare GENESIS_FILE="Genesis.json";
  if [[  "${NODE_TYPE}" == "${ROOT_NODE_TYPE}" ]]; then

    getUnconfiguredGenesisFile;

    configureGenesisFile;

    initializeBlockChain;

    createDAGfile;

  else

    declare ENODE_SPEC="";
    declare PEER_ACCT="";
    getRootNodeOperationsFiles;

  fi;

  declare MINING_SCRIPT="initialTrivialMiningScript.js";
  obtainSimpleMiningScript;

  declare BALANCE=0;
  getBaseAccountBalance;

  # geth \
  #     --datadir "${WORK_DIR}/geth" \
  #     --verbosity 5 \
  #     --maxpeers "2" \
  #     --networkid ${NETWORK_ID} \
  #     --nodiscover \
  #     console  2>> ${WORK_DIR}/prvWhsmn.log;

  # exit 1;     

  mineFirstBlocksIfZeroBalance;

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

  if [[ "${NODE_TYPE}" == "${CLIENT_NODE_TYPE}" ]]; then
    createSimpleTransactionExample;
    exit 1;
    echo -e "\n ~~ To pay to the root node's base acct use these two commands.";
    echo -e "        > personal.unlockAccount(eth.accounts[0], 'plokplok');";
    echo -e "        > eth.sendTransaction({from: eth.accounts[0], to: ${PEER_ACCT}, value: web3.toWei(1, \"ether\")})";
  fi;  

  echo -e "\n ~~ To attach from another local terminal session, use :";
  echo geth --datadir "${WORK_DIR}/geth" --networkid ${NETWORK_ID} attach ipc:/${WORK_DIR}/geth/geth.ipc
  echo "";
  echo "";

  if [[ "${NODE_TYPE}" == "${ROOT_NODE_TYPE}" ]]; then

    echo -e "\n ~~ Client nodes will need these four data elements in order to connect :";
    echo -e "    ~ The IP address of your root node machine                      :: ${LOCAL_IP_ADDR}";
    echo -e "    ~ The directory for geth's working files ON THE ROOT NODE       :: ${PROJECT_DIR}";
    echo -e "    ~ The SSH user name of the root node machine's Ethereum account :: ${USER}";
    echo -e "    ~ The SSH password of the root node machine's Ethereum account  :: ????????????";

  fi;

  echo "";
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";

  echo "Done.";
  exit 0;

else
  echo "NODE_TYPE is confused.  Can only be CLIENT or ROOT. Quitting."
  exit 1;
fi;


