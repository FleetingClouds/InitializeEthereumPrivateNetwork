#!/bin/bash

# ############################################################################
#
#      Handle loading, capturing and saving shell variables
#
# ############################################################################

set -e;
#

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
#  loadShellVars -- get shell variables from file, if exists
#
function loadShellVars() {

  echo " *************************** ${USER_VARS_FILE_NAME}";

  if [ -f ${USER_VARS_FILE_NAME} ]; then
    echo "A";
    source ${USER_VARS_FILE_NAME}
  else

    echo "B";
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

