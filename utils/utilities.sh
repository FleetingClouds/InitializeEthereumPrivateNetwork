#!/bin/bash

# ############################################################################
#
#         Utility and support functions not part of the problem domain
#
# ############################################################################

set -e;
#

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  aptNotYetInstalled -- check if installation is needed
#
function aptNotYetInstalled() {

  set +e;
  return $(dpkg-query -W --showformat='${Status}\n' $1 2>/dev/null | grep -c "install ok installed");
  set -e;

}

function checkSufficientMemory() {

  declare MINIMUM=$1;
  AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%s\n", $7 }'); 
  
  if [[  ${AVAILABLE_MEMORY} -lt ${MINIMUM}  ]]; then
    echo -e "\nMemory - ${AVAILABLE_MEMORY}MB!";
    return 0;
  fi;
#else
#  echo "Memory - ${AVAILABLE_MEMORY} : OK!";
  return 1;
}

declare LOCAL_IP_ADDR=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1');


