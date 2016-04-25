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


declare LOCAL_IP_ADDR=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1');

