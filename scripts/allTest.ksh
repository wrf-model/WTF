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


wrfTarName=`basename $TARFILE .tar`

# Guarantee that the test directory exists.
mkdir -p $TEST_DIR

# Loop over WRF platforms and types.
for choice in $CONFIGURE_CHOICES; do
   parallelType=`getParallelType $choice`

   for type in $BUILD_TYPES; do
      goodConfig=`goodConfiguration $type $parallelType`

      if $goodConfig; then
          if [ $type = "wrfplus" ]; then
             wrfDir=$BUILD_DIR/${wrfTarName}.${choice}/$type/WRFPLUSV3
          else
             wrfDir=$BUILD_DIR/${wrfTarName}.${choice}/$type/WRFV3
          fi
          regDataDir=$METDATA_DIR/$type
          NAMELIST_FILES=`getNamelists $NAMELIST_DIR/$type $parallelType`
    
          # Make sure paths exist for test inputs and namelists.
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
      fi  # test for good configuration

   done   # loop over $BUILD_TYPES

done   # loop over $CONFIGURE_CHOICES


# Now we keep this script alive until all tests are done.   This will let us string together
# this script with another that checks the results of the tests. 
# Note that on personal computers, reaching this point means that all tests are done.
if $BATCH_TEST; then
    batchWait $BATCH_QUEUE_TYPE 't\.'
fi

#  Do not exit!   This code gets "sourced" by a parent shell, and exiting causes the parent to quit. 
#  The following command should generate a return code of zero, indicating no errors.
echo ""
