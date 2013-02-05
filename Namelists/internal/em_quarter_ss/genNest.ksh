#!/bin/ksh

# Usage:  genNest.ksh <wrf_namelist_file> 
#
#  Takes an existing WRF namelist file and outputs a new one with moving nests turned on.
#  Output should be redirected to a new file with a slightly modified name. 
# 

if [ $# -ne 1 ]; then
   echo "Usage: $0 <wrf_namelist_file>" 
   exit 1
fi 

inputFile=$1

if [ ! -f $inputFile ]; then
   echo "$0: namelist file does not exist: $inputFile"
   exit 1
fi


grep run_minutes  $inputFile  | grep 2   > /dev/null 2>&1
found="( $? -eq 0 )" 
if [ ! $found ]; then
   echo "$0:  Namelist does not contain 'run_minutes = 2'"
   exit 1
fi

grep history_interval  $inputFile  | grep '= 2,'   > /dev/null 2>&1
found="( $? -eq 0 )" 
if [ ! $found ]; then
   echo "$0:  Namelist does not contain 'history_interval = 2,'"
   exit 1
fi

grep max_dom  $inputFile  | grep '= 1,'   > /dev/null 2>&1
found="( $? -eq 0 )" 
if [ ! $found ]; then
   echo "$0:  Namelist does not contain 'max_dom = 1,'"
   exit 1
fi



# Change three existing parameter values and insert some extra moving nest directives.
sed -e '/run_minutes/s/2/1/' \
    -e '/history_interval/s/2/1/' \
    -e '/max_dom/s/1,/2,/' \
    $inputFile

