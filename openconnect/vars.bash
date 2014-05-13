#!/bin/bash
#
#
#
#
#

baseDir="/root/openconnect"

# What is our VPN user called?
user="jlo"

# What is our authentication group?
authGroup="Bootylicious"

# What should the interface be called?
int="VPN0"

# Our anyconnect URL?
url="http://junk.trunk.example.com/"

# This is the script we'll be using to add our routes.
# I'm sure there is a better way, but I can't be fucked finding it
routeScript="$baseDir/routes.bash"

# These are the arguments we send to openconnect
ocArgs="-i $int -u $user --passwd-on-stdin -b"

logFile="/tmp/$(basename $0).log"

# Where is our password file?  This contains our password for the VPN
# it is prepended to the entire auth string ${pass}${token}
passFile="$baseDir/some_file_containing_my_password"

openconnect=$(which openconnect)

declare -a routes
routes=(
"10.9.0.0/16"
"10.10.9.0/24"
"192.168.1.1/32"
)

