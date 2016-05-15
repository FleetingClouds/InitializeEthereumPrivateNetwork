#!/bin/bash
#

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
            "The SSH user name of the root node machine's Ξthereum account :: " \
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
