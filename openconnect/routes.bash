#!/bin/bash
#
#
#
#

source $(dirname $0)/vars.bash

intExists=$(ifconfig $int)

if [[ -n $intExists ]]
then
  ip=$(ip addr show dev $int | grep 'inet ' | sed 's/^.*inet //; s/\/.*$//')
  for route in ${routes[*]}
  do
    if [[ -n $ip ]]
    then
      ip route add $route via $ip dev $int
    fi
  done
fi
