#!/bin/bash

# This script delivers a touch to groceries (files) if they haven't been
# modified for a certain period of time

# This be the source directory we're watching, yar!
# FUUUUUUUSE! (Say it like KHAAAAAAAN from Star Trek)
srcDir="/some/source/dir"

# Communication to your grocer is important
# Where do we write out logs yo?!
logFile="/tmp/$(basename $0).log"

# Seconds to delay for polling $srcDir
pollDelay=5

# Seconds to delay for size comparison
delay=5

# keeping track of our childrens...
declare waitpids

# Are we debugging out of here?
# Boolean values please
debug=0

# The array declarations for keeping track of our groceries that we'll deliver
# at some point
declare -a files
declare -A fileInfo

function AdmiralAckbar {
  echo -e "Exiting" >> $logFile
  if [[ -n $waitpids ]]
  then
    echo -e "Killing PIDs \c" >> $logFile
    for pid in $waitpids
    do
      if [[ -d "/proc/$pid" ]]
      then
        echo -e "$pid \c" >> $logFile
        kill -9 $pid >> $logFile
      fi
    done
    echo -e "" >> $logFile
  fi
  exit
}

function d {
  if [[ $debug != 0 ]]
  then
    echo -e "$1"
  fi
}

trap AdmiralAckbar SIGINT SIGTERM

# Just documenting ${fileInfo[$file]} format
# ${fileInfo[$file]} = COUNT : OLD SIZE : NEW SIZE
#

# processFile $file
function processFile {
  local file=$1
  local count=0
  local old
  local new
  local knownFile
  local newKnownFiles
  while [[ -f $file ]]
  do
    echo "$(date) :: $file = \$count=$count \$old=$old \$new=$new" >> $logFile

    if [[ -z $new ]]
    then
      new=$(ls -l $file | awk '{print $5}')
    else
      old=$new
      new=$(ls -l $file | awk '{print $5}')
    fi

    echo "$(date) :: $file = \$count=$count \$old=$old \$new=$new" >> $logFile

    # Do we need to get all touchy feely?
    # Not on the first date of course!
    if [[ $count -gt 0 ]]
    then
      if [[ $old = $new ]]
      then
        echo -e "$(date) :: Touching file, $file" >> $logFile
        if [[ -f $file ]]
        then
          touch $file 2>&1 >> $logFile
          while [[ -f $file ]]
          do
            echo -e "$(date) :: Waiting for ifw.pl to process $file" >> $logFile
            sleep 1
          done
        fi
      fi
    fi
    if [[ ! -f $file ]]
    then
      echo -e "$(date) :: $file has been moved" >> $logFile
    fi
    ((count++))
    sleep $delay
  done
}

echo -e "$(date) :: Starting up!" >> $logFile

while true
do
  files=$(find $srcDir -maxdepth 1 -type f)
  if [[ -n $files ]]
  then
    for file in ${files[*]}
    do
      processed=0
      if [[ -n $knownFiles ]]
      then
        for knownFile in $knownFiles
        do
          d "${knownFile##*:}"
          d "$(ls -l /proc/${knownFile##*:}/stat)"
          if [[ -f "/proc/${knownFile##*:}/stat" ]]
          then
            processed=1
            thisKnownFiles="$thisKnownFiles $knownFile"
          fi
        done
      fi

      d "$(date) :: \$processed = $processed : \$thisKnownFiles == $thisKnownFiles"
      d "$(date) :: \$processed = $processed : \$knownFiles == $knownFiles"

      # It's a bit ugly, just like this script!
      knownFiles=$thisKnownFiles
      unset thisKnownFiles

      if [[ $processed != 1 ]]
      then
        processFile ${file%%:*} &
        pid=$!
        waitpids="$waitpids $pid"
        knownFiles="$knownFiles $file:$pid"
        echo -e "$(date) :: \$knownFiles == $knownFiles"
      fi
    done
  fi

  # Whoah! Wait for $delay, thank you, come again!
  sleep $pollDelay
done
