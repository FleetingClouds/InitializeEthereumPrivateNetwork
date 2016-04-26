#!/bin/bash
#

source .userVars.sh

declare WORK_DIR=${HOME}/${PROJECT_DIR};
declare GETH_PATH=${WORK_DIR}/geth;
declare IPC_ENDPOINT=${GETH_PATH}/geth.ipc;

declare INITIAL_FILES_ARCHIVE="/tmp/initialFiles.tar.gz";
declare GENESIS_FILE="Genesis.json";
declare CHAINDATA_DIR="geth/chaindata";
declare NODE_INFO_FILE="nodeInfo.json";

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
echo "Host node reports : \"Collecting client initialization files from ${DIR} into ${INITIAL_FILES_ARCHIVE}\"";

cd ${DIR};

declare GETH_CONSOLE_RUNNING=$(ps aux | grep geth | grep -c console);
declare GETH_CONNECTION_TYPE="console";

if [[  ${GETH_CONSOLE_RUNNING} -gt 0  ]]; then GETH_CONNECTION_TYPE="attach"; fi;
echo "Host node reports : \"Geth usage type is : ${GETH_CONNECTION_TYPE}\"";
# echo "Type : ${GETH_CONNECTION_TYPE}";

geth \
    --datadir ${GETH_PATH} \
    --verbosity 0 \
    --networkid ${NETWORK_ID} \
    --exec admin.nodeInfo \
  ${GETH_CONNECTION_TYPE} ipc:/${IPC_ENDPOINT} > ${NODE_INFO_FILE};


tar \
    --create \
    --gzip \
    --file ${INITIAL_FILES_ARCHIVE} \
  ${GENESIS_FILE} \
  ${CHAINDATA_DIR} \
  ${NODE_INFO_FILE};

echo "Host node reports : \"The file ${INITIAL_FILES_ARCHIVE}\" is ready for pick up.";
