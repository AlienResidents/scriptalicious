#!/bin/bash
#
# Exit codes:
# 100 : must run this as root
# 110 : password file not found
# 120 : openconnect command not found
# 130 : invalid rsa token given
#

source $(dirname $0)/vars.bash

iAm=$(whoami)
if [[ $iAm != 'root' ]]
then
  echo -e "You need to be root, exiting."
  exit 100
fi

if [[ ! -f $passFile ]]
then
  echo -e "The password file doesn't exist, exiting."
  exit 110
else
  pass=$(cat $passFile)
fi

if [[ -z $openconnect ]]
then
  echo -e "the openconnect command can't be found, exiting."
  exit 120
fi

isRunning=$(pgrep -f $openconnect)
if [[ -n $isRunning ]]
then
  echo -e "Stopping current process(es)... "
  echo $isRunning | xargs kill
fi

echo -e "What is your token pin? [] \c"
read token
if [[ -z $token || $token =~ [^0-9] || ${#token} != '6' ]]
then
  echo -e "The token, \"$token\", seems like an invalid token, try again"
  exit 130
fi

echo "${pass}${token}" | $openconnect $ocArgs --authgroup="$authGroup" $url >> $logFile 2>> $logFile
retval=$?

intIP=$(ip addr show dev $int | grep 'inet ')
#echo -e "intIP == \"$intIP\""
while [[ -z $intIP ]]
do
  sleep 1
  intIP=$(ip addr show dev $int | grep 'inet ')
  #echo -e "intIP == \"$intIP\""
done
echo -e "Running route script..." >> $logFile
$routeScript >> $logFile
