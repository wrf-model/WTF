#!/usr/bin/env python

import os
import sys
import getopt
import re
import shutil
import subprocess
import time

# Import common functions
import common

## run_WRF_Tests.ksh
##
## Top-level script for running a set of regression tests for WRF. 
## 
## This script must be passed a "WRF Test File" (with a *.wtf filename extension), which 
## contains shell variable definitions for important user-specified parameters, such as 
## the directory pathnames for different test suite components.   One WRF Test File should 
## be created for each particular machine-compiler combination, such as "Linux with gfortran",
## or "<my_computer_name> with pgi".    
##
##  Author: Brian Bonnlander
##  Modification history:
##          Sep 2016, Michael Kavulich, Jr.: Ported original ksh script to python
##          Oct 2016, "                    : Script can be run directly from command line, or the function run_test can be
##                                              called from any other script

get_local_code=False
get_github_code=True
list_of_wrfs_to_test=["/Users/kavulich/WRFDA_REGTEST/WRF"]
list_of_github_urls=["https://github.com/wrf-model/WRF"]
list_of_github_branches=["master"]

def usage():
   print("\nUsage: " + __file__ + " TEST_FILE.wtf")
   sys.exit(1)
## Start of main program

if __name__ == "__main__":
    # execute only if run as a script
    main()

def main():

 print("Starting script " + __file__)
##
## Parse command line and set WRF test file name.
## Check that the file exists and has a ".wtf" extension
##

 if not len(sys.argv)==2:
    print("\nError: you must specify a test file\n")
    usage()

 testfile=sys.argv[1]
 if testfile.rsplit('.', 1)=="wtf":
    if not os.path.isfile(testfile)
       print("\nError: test file " + testfile + " does not exist!\n")
       usage()
 else:
    print("Error: Test files must end in '.wtf' extension")
    usage()

 starttime = time.asctime( time.localtime(time.time()) )
 print "Starting WTF :", starttime

 run_test(testfile)

 endtime = time.asctime( time.localtime(time.time()) )
 print "WTF done:", endtime


def run_test(testfile):

##  Import settings from the WTF master control file. 
   read_wtf(testfile)


##
##  Check that a few critical variables are set, such as the pathname of the WRF source tarfile.
##  If so, run the top-level build script, and verify no error before continuing. 
## 

#if [[ -z $NUM_PROC_BUILD ]]  || [[ -z $TARFILE_DIR ]]; then 
#   echo "$0: Error: specified WRF Test File failed to specify key variables; exiting."
#   exit 1
#fi


##  Create a list of all build options to pass to "configure". 
#export CONFIGURE_CHOICES=`echo $CONFIGURE_SERIAL $CONFIGURE_OPENMP $CONFIGURE_MPI`


## Get WRF copies to build

if get_local_code:
   get_wrfs_local(list_of_wrfs_to_test)

if get_github_code:
   get_wrfs_github(list_of_github_urls,list_of_github_branches)

if not (get_local_code or get_github_code):
   print("You must test either local code or code from github")
   sys.exit(1)

tarFiles=`ls $TARFILE_DIR/*.tar`
if [ -z "$tarFiles" ]; then
   echo "WTF:  Error: no WRF source tarfiles found in $TARFILE_DIR!"
   echo "   All WRF source tarfiles must end in '*.tar'."
   exit 2
fi

##
##  Loop over all WRF source tarfiles.
##
debug_allCheck=false
for TARFILE in $tarFiles; do

    if ! $debug_allCheck; then
        ## Run top-level build script
        . $WRF_TEST_ROOT/scripts/allBuild.ksh  
        if [ $? -ne 0 ]; then
           echo "$WRF_TEST_ROOT/scripts/allBuild.ksh returned $?; aborting!"
           exit 255
        fi 

        ## Run top-level testing script
        . $WRF_TEST_ROOT/scripts/allTest.ksh  
        retCode=$?
        if [ $retCode -ne 0 ]; then
           echo "$WRF_TEST_ROOT/scripts/allTest.ksh returned $retCode; aborting!"
           exit 255
        fi 
     fi
 
    ## Run script to generate summary of test results.
    . $WRF_TEST_ROOT/scripts/allCheck.ksh  
    
done
