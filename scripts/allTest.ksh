#!/bin/ksh

## allTest.ksh
##  
##  Template script for running a batch of WRF regression tests on a particular WRF tar-file.
##  
##  Author: Brian Bonnlander
##

if $DEBUG_WTF; then
   set -x
fi


# Include common functions
. $WRF_TEST_ROOT/scripts/Common.ksh


##
##  Get the list of namelist files.  This depends on the WRF communication framework ($parallelType 
##  in the code) because some tests are known to fail with OpenMP builds.  
##
getNamelists()
{
   namelistDir=$1
   parallelType=$2
   
   # Basic set of namelists
   namelists=`ls $namelistDir/namelist.input.*`
   extra=''
   
   # Extra namelists for specific communication configuration choices
   case $parallelType in
      serial)  extra=`ls $namelistDir/SERIAL/namelist.input.* 2> /dev/null` 
               ;;
      openmp)  extra=`ls $namelistDir/OPENMP/namelist.input.* 2> /dev/null` 
               ;;
         mpi)  extra=`ls $namelistDir/MPI/namelist.input.* 2> /dev/null` 
	       ;;
   esac
   namelists="$namelists $extra"
   echo $namelists
}


wrfTarName=`basename $TARFILE .tar`


# Loop over WRF platforms and types.
for choice in $CONFIGURE_CHOICES; do

   parallelType=`getParallelType $choice`

   for type in $BUILD_TYPES; do
      wrfDir=$BUILD_DIR/${wrfTarName}.${choice}/$type/WRFV3
      regDataDir=$METDATA_DIR/$type
   
      NAMELIST_FILES=`getNamelists $NAMELIST_DIR/$type $parallelType`
      if [ -z $NAMELIST_FILES ]; then
        echo "$0: Error: namelist.input files not found in directory $NAMELIST_DIR/$type/"
        exit 2
      fi
      if [ ! -d $regDataDir ]; then
         echo "$0: Regression data directory does not exist: $regDataDir"
         exit 2
      fi

      banner "`date`: Started suite of tests for ${wrfDir} ..."
   
      # Loop over namelist files; one per test.
      for nf in $NAMELIST_FILES; do
          namelist=`basename $nf`
          wrfBase=$wrfTarName
          testDir=$TEST_DIR/${wrfBase}.${choice}/$type/wrf_regression.${namelist}
          banner "`date`: Starting test for ${testDir} ..."
          $WRF_TEST_ROOT/scripts/testWrf.ksh -G $BATCH_ACCOUNT -d $testDir -t $wrfDir -m $regDataDir -n $nf -par $parallelType -wt $type  
          banner "`date`: Ending test for ${testDir} ..."
      done
   
      banner "`date`: Ended suite of tests for ${wrfDir} ..."
   done   # loop over $BUILD_TYPES
done   # loop over $CONFIGURE_CHOICES


# Now we keep this script alive until all tests are done.   This will let us string together
# this script with another that checks the results of the tests. 
# Note that on personal computers, reaching this point means that all tests are done.
if $BATCH_TEST; then
    OS_NAME=`uname`
    case $BATCH_QUEUE_TYPE in
        LSF) JOBS=`bjobs -w | grep 't\.'`
             while [ -n "$JOBS" ]; do
                 sleep 60
                 JOBS=`bjobs -w | grep 't\.'`
             done
	     ;;
        NQS) JOBS=`qstat -u bonnland | grep bonnland | grep 't\.' | awk '{print $10}' | grep -v C`
             while [ -n "$JOBS" ]; do
                 sleep 60
                 JOBS=`qstat -u bonnland | grep bonnland | grep 't\.' | awk '{print $10}' | grep -v C`
	         echo JOBS="$JOBS"
             done
	     ;;
    esac
fi

#  Do not exit!   This code gets "sourced" by a parent shell, and exiting causes the parent to quit. 
#  The following command should generate a return code of zero, indicating no errors.
echo ""
