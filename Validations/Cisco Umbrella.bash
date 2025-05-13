#!/bin/bash

####################################################################################################
#
# ABOUT
#
#   A script which determines the health of Cisco Umbrella
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 22-Dev-2023, Dan K. Snelson (@dan-snelson)
#       Original version
#
#   Version 0.0.2, 19-Jan-2024, Dan K. Snelson (@dan-snelson)
#       Updated for Extension Attribute Usage
#
#   Version 0.0.3, 26-Jan-2024, Dan K. Snelson (@dan-snelson)
#       Updated for console-side updates (which unload the System Extension)
#
#   Version 0.0.4, 13-May-2025, Dan K. Snelson (@dan-snelson)
#       Updated for macOS 15.5 information transfers
#
#   Version 0.0.5, 13-May-2025, Dan K. Snelson (@dan-snelson)
#       Added a retry loop for failed filter check
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.5"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# The number of attempts to get information from the Falcon Service (with a ten second sleep after each attempt).
retries="3"



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for running processes (supplied as Parameter 1)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function procesStatus() {

    processToCheck="${1}"
    status=$( pgrep -x "${processToCheck}" )
    if [[ -n ${status} ]]; then
        processCheckResult+="'${processToCheck}' Running; "
    else
        processCheckResult+="'${processToCheck}' Failed; "
    fi

}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Cisco Umbrella
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Validate Cisco Umbrella System Extension
systemExtensionTest=$( systemextensionsctl list | awk -F"[][]" '/com.cisco.anyconnect.macos.acsockext/ {print $2}' )

case "${systemExtensionTest}" in
    *"activated enabled"*   ) processCheckResult="'System Extension' Running; " ;;
    *                       ) processCheckResult="'System Extension' Failed; " ;;
esac

# Validate various Cisco Umbrella Processes
procesStatus "com.cisco.anyconnect.macos.acsockext"

# Validate Cisco Umbrella Protection
protectionStatus=$( curl -s http://examplemalwaredomain.com )

# Retry loop for failed filter check
counter=1
until [[ "${protectionStatus}" == *"malware.opendns.com"* ]] || [[ "${counter}" -gt "${retries}" ]]; do
    echo "Check ${counter} of ${retries} …"
    sleep 10
    protectionStatus=$( curl -s http://examplemalwaredomain.com )
    ((counter++))
done

# Output various conditions
case $protectionStatus in
    *"malware.opendns.com"* )
        processCheckResult+="Filter Active; "
        ;;
    *"301 Moved Permanently"* )
        processCheckResult+="Filter Failed; "
        ;;
    * )
        processCheckResult+="Filter Unknown; "
        ;;
esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Output Results
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Remove trailing "; "
processCheckResult=${processCheckResult/%; }

case "${processCheckResult}" in
    *"Failed"*  ) RESULT="At least one service failed: ${processCheckResult}" ;;
    *           ) RESULT="All Services Running" ;;
esac

echo "${RESULT}"