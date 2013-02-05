#!/bin/ksh

## allClean.ksh
##  
##  Script for deleting prior builds, tests, and results.  This brings the WTF
##  directory structure back to a "pristine" state.  
##
##  Author: Brian Bonnlander
##

set -x 

##
## Usage:  rootDir=`getTestRootDir`
##
##  Returns the root directory of the WRF Test Suite, based on the path to this script.
##  This script should be located in $TEST_ROOT/scripts/.   The function returns $TEST_ROOT
##  as an absolute path.
##
getTestRootDir()
{
   curr=`pwd` 
   cd `dirname $0` 
   scriptDir=`pwd` 
   cd $curr 
   rootDir=`dirname $scriptDir`
   echo $rootDir
}


# Define relevant directories.
WTF_ROOTDIR=`getTestRootDir`
BUILD_DIR=$WTF_ROOTDIR/Builds
RUNS_DIR=$WTF_ROOTDIR/Runs
TRASH_DIR=$WTF_ROOTDIR/.Trash.$$

# Make sure builds and runs directories exist.
if [[ ! -d $BUILD_DIR ]] ||  [[ ! -d $RUNS_DIR ]] ; then
   echo "$0: Please update the clean script to reflect your directory names:"
   echo "      BUILD_DIR is currently '$BUILD_DIR'"
   echo "      RUNS_DIR is currently '$RUNS_DIR'"
   echo "  ...aborting. "
   exit 255
fi

# Move builds and runs directory to trash directory. 
mkdir $TRASH_DIR
if [ $? != 0 ] ; then
   echo "$0: Could not create Trash folder '$TRASH_DIR'"
   echo "  ...aborting. "
   exit 255
fi 
   
mv $BUILD_DIR $RUNS_DIR $TRASH_DIR
if [ $? != 0 ] ; then
   echo "$0: Could not move BUILDS_DIR and RUNS_DIR to '$TRASH_DIR'"
   echo "  ...aborting. "
   exit 255
fi 

# Recreate builds and runs directory. 
mkdir $BUILD_DIR $RUNS_DIR

# Delete trash directory in the background. 
\rm -rf $TRASH_DIR   &
if [ $? != 0 ] ; then
   echo "$0: Could not delete trash directory '$TRASH_DIR'"
   echo "  ...aborting. "
   exit 255
fi 

# Exit with no error.
echo "$0: success!"
exit 0

