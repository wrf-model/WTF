#!/bin/ksh

## allCheck.ksh
##  
##  Script for determining if a set of WRF tests passed or failed. 
##
##  NOTE: If this script is re-run, all old test results are removed, and all checks are made again.
##  
##  Author: Brian Bonnlander
##


if $DEBUG_WTF; then
   set -x
fi


# Include common functions
. $WRF_TEST_ROOT/scripts/Common.ksh



## 
## Get a single-line summary of a test as a formatted string.
##
writeTestSummary()
{
   wrfFlavor_wt=$1      #  e.g. em_real, em_chem
   namelistFile_wt=$2   #  e.g. namelist.input.2
   parType_wt=$3        #  e.g. serial, openmp, dmpar
   variation_wt=$4      #  e.g. Standard, Quilting, Adaptive
   testType_wt=$5       #  e.g. FCAST, BFB, COMPILE
   outcome_wt=$6        #  e.g. PASS, FAIL, PASS_MANUAL

   # Fixed-format output thanks to ksh printf
   printf "%-13s %-22s %-7s %-10s %-8s %-11s\n" \
     ${wrfFlavor_wt} ${namelistFile_wt} ${parType_wt} ${variation_wt} ${testType_wt} ${outcome_wt} >> $SUMMARY_FILE
}



##
## Get the long-form name of a test variation encoded in the last two letters of the namelist file.
## If there is no two-letter code at the end of the name, the variation is called a "Standard" test.
##
getVariationName()
{
   namelist_gv=$1
   strlen=${#namelist_gv}
   variationCode=`echo $namelist_gv | cut -c $(($strlen-1))-$strlen`
   case $variationCode in
     AD)  variationName='Adaptive ' 
          ;;
     BN)  variationName='Binary   ' 
          ;;
     DF)  variationName='DFI      ' 
          ;;
     FD)  variationName='FDDA     ' 
          ;;
     GR)  variationName='Grib1    ' 
          ;;
     NE)  variationName='Nesting  ' 
          ;;
     QT)  variationName='Quilting ' 
          ;;
     *)   variationName='Standard ' 
          ;;
   esac
   echo $variationName
}


##
## Usage: `writeForecastResult $parallelType $testDir $wrfType $namelist $parType $variation $testType`
##
## Writes the outcome of a forecast to a summary file.
##
writeForecastResult()
{
   parallelType_wf=$1
   testDir_wf=$2
   wrftype_wf=$3
   nlist_wf=$4
   vtion_wf=$5
   testtype_wf=$6

   if [[ ! -f $testDir_wf/wrf.exe ]]; then
       touch $testDir_wf/FAIL_COMPILE.tst
       result="FAIL_COMPILE"
   else
       success_wf=`checkForecastResult $parallelType_wf $testDir_wf`
       if [ "$success_wf" = "true" ];  then
           touch $testDir_wf/SUCCESS_FCST.tst
           result="PASS"
       else
           touch $testDir_wf/FAIL_FCST.tst
           result="FAIL"
       fi
   fi
   # Write a formatted line to the "results file". 
   writeTestSummary $wrftype_wf $nlist_wf $parallelType_wf $vtion_wf $testtype_wf $result
}



##
## Usage: writeBitForBit $checkFile $compareFile $checkDir $wrfType $namelist $parType $variation $testType  
##
## Compares a parallel-created wrfout file against a serial-created wrfout file and writes a summary to the results file.
##
writeBitForBit()
{
    set -x

    checkFile_wb=$1
    compareFile_wb=$2
    wrfType_wb=$3
    namelist_wb=$4
    parType_wb=$5
    variation_wb=$6
    testType_wb=$7

    checkDir_wb=`dirname $checkFile_wb`
    compareDir_wb=`dirname $compareFile_wb`

    cd $checkDir_wb
    outputForm_wb=`grep io_form_history $checkDir_wb/namelist.input | cut -d '=' -f 2 | awk '{print $1;}'`
    case $outputForm_wb in 
        1) $checkDir_wb/diffwrf $compareFile_wb $checkFile_wb > /dev/null 2>&1            # Binary output
	   ;;
        2) $checkDir_wb/diffwrf $compareFile_wb $checkFile_wb > /dev/null 2>&1            # NetCDF output
	   ;;
        5) $checkDir_wb/diffwrf $compareFile_wb $checkFile_wb $checkDir_wb > /dev/null 2>&1  # Grib1 output
	   ;;
        *) echo "$0: unknown WRF output format: $outputForm_wb" 
           exit 2
    esac

    # Determine the *.tst filenames depending on whether this is an OPENMP or MPI test.
    case $parType_wb in
       openmp)  failFile=FAIL_BFB_OMP.tst 
                successFile=SUCCESS_BFB_OMP.tst
		;;
       mpi)     failFile=FAIL_BFB_MPI.tst 
                successFile=SUCCESS_BFB_MPI.tst
		;;
       *)    echo "$0: unknown parallel type: $parType_wb"
             exit 3
    esac

    if [ -e $checkDir_wb/fort.* ]; then 
       touch $checkDir_wb/$failFile
       touch $compareDir_wb/$failFile
       result_wb="FAIL"
    else
       touch $checkDir_wb/$successFile
       touch $compareDir_wb/$successFile
       result_wb="PASS"
    fi 
    
    # Write a formatted line to the "results file". 
    writeTestSummary $wrfType_wb $namelist_wb $parType_wb $variation_wb $testType_wb $result_wb
}


mkdir -p ${TEST_DIR}/RESULTS


# The ID string for this particular test; it is typically something like "wrf_<svn#>"
TEST_ID=`basename $TARFILE .tar`

# The path to the file containing a summary of all test results
export SUMMARY_FILE=${TEST_DIR}/RESULTS/${TEST_ID}.`date +"%Y-%m-%d_%T"`

echo "Test results will be summarized in '$SUMMARY_FILE'."


## 
## Write a header line in the summary file.  
##
echo "# Arch=`hostname`, WTF_Config='$TEST_FILE_FULL', Config_OPTS='$CONFIGURE_CHOICES'" > $SUMMARY_FILE


##
## Loop over all WRF platforms, types, and tests:   for each test, find out if the forecast 
##   was successful and indicate by creating one of two files:  SUCCESS_FCST.tst or FAIL_FCST.tst
## 
## "testCounter" counts the number of tests running in the background; a "wait" is performed when 
##   this counter reaches $NUM_PROC_TEST, and then it is reset. 
##
testType="FCST"
testCounter=0
echo CONFIGURE_CHOICES == $CONFIGURE_CHOICES
for configOpt in $CONFIGURE_CHOICES; do
   parType=`getParallelType $configOpt`

   for wrfType in $BUILD_TYPES; do
      goodConfig=`goodConfiguration $wrfType $parType`

      if $goodConfig; then
    
          testBase=$TEST_DIR/$TEST_ID.$configOpt/$wrfType
          if [ ! -d $testBase ]; then
              echo "$0: directory does not exist: $testBase; something broke!"
              exit 2
          fi
       
          # Get the namelists being run for this WRF flavor and parallel type. 
          NAMELIST_FILES=`getNamelists $NAMELIST_DIR/$wrfType $parType`
    
          # Loop over directories for specific tests.
          for nf in $NAMELIST_FILES; do
              namelist=`basename $nf`
              checkDir=${testBase}/wrf_regression.${namelist}
              if [ ! -d $checkDir ]; then
                 echo "$0: directory does not exist: '$checkDir'; something broke!"
                 exit 2
              fi
     
              # Find whether this is a standard test or a variation; the final two characters in the 
              # namelist file will be capital letters if it is a particular variation
              variation=`getVariationName $namelist`
    
              # If this is a non-standard variation, the namelist string should be truncated to remove 
              # the variation code.
              if [[ $variation != "Standard" ]]; then
                  strlen=${#namelist}
                  strlen=$(($strlen-2))
                  namelist=`echo $namelist | cut -c 1-$strlen`
              fi
              
              # erase previous check results. 
              \rm -f $checkDir/*.tst  
              \rm -f $checkDir/fort.*
    
              writeForecastResult $parType $checkDir $wrfType $namelist $variation $testType &
    
              testCounter=$((testCounter + 1))
    	  echo testCounter == $testCounter
    	  if [ $testCounter -ge $NUM_PROC_TEST ]; then
    	      jobs
    	      wait
    	      testCounter=0
    	  fi
    
          done   # Loop over tests

      fi  # if good configuration
   
   done  # Loop over WRF flavors

done   # Loop over WRF parallel options

set -x

# Wait for all forecast results to be written by child processes.
wait


# Non-serial WRF runs will have their output tested bit-for-bit against output 
# produced by the serial version of WRF.
WRF_COMPARE_PLATFORMS="$CONFIGURE_OPENMP $CONFIGURE_MPI"
serialOption=$CONFIGURE_SERIAL


##
## Loop over openmp and mpi tests: determine if results are bit-for-bit with serial results and 
## indicate by creating a "BFB" file.
##
serialTestDir="$TEST_DIR/$TEST_ID.$serialOption"

testType="BFB"
testCounter=0
for configOpt in $WRF_COMPARE_PLATFORMS; do

   parType=`getParallelType $configOpt`

   for wrfType in $BUILD_TYPES; do

      goodConfig=`goodConfiguration $wrfType $parType`

      if $goodConfig; then
          testBase="$TEST_DIR/$TEST_ID.$configOpt/$wrfType"
          if [ ! -d $testBase ]; then 
              echo "$0: There are no tests in the non-serial directory '$testBase'; something broke!"
              exit 2
          fi
       
          # Find out which tests exist for the current parallel build type;
          # there are often fewer WRF flavors for openmp than for serial or mpi.
          #typeDirs=`ls $TEST_DIR/$TEST_ID.$configOpt`
          NAMELIST_FILES=`getNamelists $NAMELIST_DIR/$wrfType $parType`
    
          #for dir in $testDirs; do
          for nf in $NAMELIST_FILES; do
              namelist=`basename $nf`
                 
              checkDir=${testBase}/wrf_regression.${namelist}
              compareDir=${serialTestDir}/${wrfType}/wrf_regression.${namelist}
              if [ ! -d $checkDir ]; then
                 echo "$0: non-serial test directory does not exist: '$checkDir'; something broke!"
                 exit 2
              fi
              if [ ! -d $compareDir ]; then
                 echo "$0: serial test directory does not exist: '$compareDir'; something broke!"
                 exit 2
              fi
      
              # Find whether this is a standard test or a variation; the final two characters in the
              # namelist file will be capital letters if it is a particular variation
              variation=`getVariationName $namelist`
    
              # If this is a non-standard variation, the namelist string should be truncated to remove
              # the variation code.
              if [[ $variation != "Standard" ]]; then
                  strlen=${#namelist}
                  strlen=$(($strlen-2))
                  namelist=`echo $namelist | cut -c 1-$strlen`
              fi
    
              # If either the serial or non-serial forecast didn't succeed, then the bit-for-bit
              # test fails trivially, so only report a bit-for-bit test result if both forecasts succeeded. 
              checkTest1=$checkDir/SUCCESS_FCST.tst
              checkTest2=$compareDir/SUCCESS_FCST.tst
              if [ -f $checkTest1 -a -f $checkTest2 ]; then
                 checkFile=$checkDir/wrfout_d01*
                 compareFile=$compareDir/wrfout_d01*
                 writeBitForBit $checkFile $compareFile $wrfType $namelist $parType $variation $testType  &
                 testCounter=$((testCounter + 1))
	      else
	         # Create FAIL_BFB files as a way of triggering a test re-run next time. 
	         case $parType in
		    openmp)   touch $checkDir/FAIL_BFB_OMP.tst
		              touch $compareDir/FAIL_BFB_OMP.tst  ;;
		    mpi)      touch $checkDir/FAIL_BFB_MPI.tst
		              touch $compareDir/FAIL_BFB_MPI.tst  ;;
		    *)
		 esac
              fi
    
              if [ $testCounter -ge $NUM_PROC_TEST ]; then
                 jobs
                 wait
                 testCounter=0
              fi
            
          done   # Loop over tests

      fi   # if good configuration

   done   # Loop over WRF flavors

done    # Loop over WRF parallel options


# Make sure all "write to summary file" jobs are done; then sort results for easier
# comparison to other files.  

wait
mv $SUMMARY_FILE ${SUMMARY_FILE}_tmp
sort ${SUMMARY_FILE}_tmp > $SUMMARY_FILE
\rm ${SUMMARY_FILE}_tmp


#  Do not exit!   This code gets "sourced" by a parent shell, and exiting causes the parent to quit. 



