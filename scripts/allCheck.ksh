#!/bin/ksh

#BSUB -a poe                            # at NCAR: bluevista
#BSUB -R "span[ptile=32]"               # how many tasks per node (up to 8)
#BSUB -n 32                             # number of total tasks
#BSUB -o AllCheck.out                   # output filename (%J to add job id)
#BSUB -e AllCheck.err                   # error filename
#BSUB -J AllCheck                       # job name
#BSUB -q premium                        # queue
#BSUB -W 0:15                           # wallclock time
#BSUB -P 64000400
##BSUB -P 66770001

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
   wrfFlavor=$1      #  e.g. em_real, em_chem
   namelistFile=$2   #  e.g. namelist.input.2
   buildType=$3      #  e.g. serial, openmp, dmpar
   variation=$4      #  e.g. Standard, Quilting, Adaptive
   testType_wt=$5       #  e.g. FCAST, BFB, COMPILE
   outcome_wt=$6     #  e.g. PASS, FAIL, PASS_MANUAL

   # Tab-separated output fields
   echo "${wrfFlavor}	${namelistFile}	${buildType}	${variation}	${testType_wt}	${outcome_wt}" >> $SUMMARY_FILE
}



##
## Get the long-form name of a test variation encoded in the last two letters of the namelist file.
## If there is no two-letter code at the end of the name, the variation is called a "Standard" test.
##
getVariationName()
{
   namelist=$1
   strlen=${#namelist}
   variationCode=`echo $namelist | cut -c $(($strlen-1))-$strlen`
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
## Usage: `writeForecastResult $parallelType $testDir $wrfType $namelist $buildType $variation $testType`
##
## Writes the outcome of a forecast to a summary file.
##
writeForecastResult()
{
   parallelType=$1
   testDir=$2
   wrftype=$3
   nlist=$4
   buildtype=$5
   vtion=$6
   testtype=$7

   if [[ ! -f $testDir/wrf.exe ]]; then
       touch $testDir/FAIL_COMPILE.tst
       result="FAIL_COMPILE"
   else
       success=`checkForecastResult $parallelType $testDir`
       if $success;  then
           touch $testDir/SUCCESS_FCST.tst
           result="PASS"
       else
           touch $testDir/FAIL_FCST.tst
           result="FAIL"
       fi
   fi
   # Write a formatted line to the "results file". 
   writeTestSummary $wrftype $nlist $buildtype $vtion $testtype $result
}



##
## Usage: writeBitForBit $checkFile $compareFile $checkDir $wrfType $namelist $buildType $variation $testType  
##
## Compares a parallel-created wrfout file against a serial-created wrfout file and writes a summary to the results file.
##
writeBitForBit()
{
    set -x

    checkFile=$1
    compareFile=$2
    checkDir=$3
    wrfType=$4
    namelist=$5
    buildType=$6
    variation=$7
    testType=$8

    cd $checkDir
    outputForm=`grep io_form_history $checkDir/namelist.input | cut -d '=' -f 2 | awk '{print $1;}'`
    case $outputForm in 
        1) $checkDir/diffwrf $compareFile $checkFile > /dev/null 2>&1            # Binary output
	   ;;
        2) $checkDir/diffwrf $compareFile $checkFile > /dev/null 2>&1            # NetCDF output
	   ;;
        5) $checkDir/diffwrf $compareFile $checkFile $checkDir > /dev/null 2>&1  # Grib1 output
	   ;;
        *) echo "$0: unknown WRF output format: $outputForm" 
           exit 2
    esac

    if [ -e $checkDir/fort.* ]; then 
       touch $checkDir/FAIL_BFB.tst
       result="FAIL"
    else
       touch $checkDir/SUCCESS_BFB.tst
       result="PASS"
    fi 
    
    # Write a formatted line to the "results file". 
    writeTestSummary $wrfType $namelist $buildType $variation $testType $result 
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
for configOpt in $CONFIGURE_CHOICES; do

   buildType=`getParallelType $configOpt`

   for wrfType in $BUILD_TYPES; do

      testBase=$TEST_DIR/$TEST_ID.$configOpt/$wrfType

      if [ -d $testBase ]; then
         testDirs=`ls $testBase`
         
         if [ -z "$testDirs" ]; then
            echo "$0: There are no tests in the directory '$testDirs'; something broke!"
            exit 2
         fi
   
         # Loop over directories for specific tests.
         for dir in $testDirs; do
             checkDir=$testBase/$dir
             if [ ! -d $checkDir ]; then
                echo "$0: directory does not exist: '$testDirs'; something broke!"
                exit 2
             fi
   
             # Isolate the namelist filename for this test.
             namelist=`basename $dir`
             namelist=${namelist##wrf_regression.}

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
             \rm -f $checkDir/*FCST*.tst  
             \rm -f $checkDir/*BFB*.tst  
             \rm -f $checkDir/fort.*

             # Write a summary line for whether the compilations needed for the test were successful.
	     #result="FAIL"
	     #if [ -f $checkDir/SUCCESS_COMPILE.tst ]; then
	     #    result="PASS"
	     #fi
             #writeTestSummary $wrfType $namelist $buildType $variation COMPILE $result 
   
             # Find out if forecast was successful and write a summary line.
	     # Put test in the background to take advantage of multiple processors. 
             writeForecastResult $buildType $checkDir $wrfType $namelist $buildType $variation $testType &

             testCounter=$((testCounter + 1))
	     echo testCounter == $testCounter
	     if [ $testCounter -ge $NUM_PROC_TEST ]; then
		   jobs
		   wait
		   testCounter=0
	     fi
              
         done   # Loop over tests
   
      fi   # Check for test directories

   done  # Loop over WRF flavors

done   # Loop over WRF parallel options


# Wait for all forecast results to be written by child processes.
wait


# Non-serial WRF runs will have their output tested bit-for-bit against output 
# produced by the serial version of WRF.
WRF_COMPARE_PLATFORMS=""
serialOption="UNKNOWN"
for f in $CONFIGURE_CHOICES; do
   parType=`getParallelType $f`
   if [[ $parType == "serial" ]]; then
      serialOption=$f
   else
      WRF_COMPARE_PLATFORMS="$WRF_COMPARE_PLATFORMS $f"
   fi
done



##
## Loop over openmp and mpi tests: determine if results are bit-for-bit with serial results and 
## indicate by creating one of two files:  SUCCESS_BFB.tst or FAIL_BFB.tst
##
serialTestDir="$TEST_DIR/$TEST_ID.$serialOption"

testType="BFB"
for configOpt in $WRF_COMPARE_PLATFORMS; do

   buildType=`getParallelType $configOpt`

   # Find out which tests exist for the current parallel build type;
   # there are often fewer WRF flavors for openmp than for serial or mpi.
   typeDirs=`ls $TEST_DIR/$TEST_ID.$configOpt`

   for wrfType in $typeDirs; do

      testBase="$TEST_DIR/$TEST_ID.$configOpt/$wrfType"

      if [ -d $testBase ]; then 
         testDirs=`ls $testBase`
         
         if [ -z "$testDirs" ]; then
            echo "$0: There are no tests in the non-serial directory '$testDirs'; something broke!"
            exit 2
         fi
   
         for dir in $testDirs; do
             
             checkDir=$testBase/$dir
             compareDir=$serialTestDir/$wrfType/$dir
             if [ ! -d $checkDir ]; then
                echo "$0: non-serial test directory does not exist: '$checkDir'; something broke!"
                exit 2
             fi
             if [ ! -d $compareDir ]; then
                echo "$0: serial test directory does not exist: '$compareDir'; something broke!"
                exit 2
             fi
   
             # Isolate the namelist filename for this test.
             namelist=`basename $dir`
             namelist=${namelist##wrf_regression.}

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
                writeBitForBit $checkFile $compareFile $checkDir $wrfType $namelist $buildType $variation $testType  &
                testCounter=$((testCounter + 1))
             fi

	     if [ $testCounter -ge $NUM_PROC_TEST ]; then
	        jobs
	        wait
	        testCounter=0
	     fi

         done   # Loop over tests

      fi  # Check for test directories

   done   # Loop over WRF flavors

done    # Loop over WRF parallel options


# Make sure all "write to summary file" jobs are done; then sort results for easier
# comparison to other files.  

wait
mv $SUMMARY_FILE ${SUMMARY_FILE}_tmp
sort ${SUMMARY_FILE}_tmp > $SUMMARY_FILE
\rm ${SUMMARY_FILE}_tmp


#  Do not exit!   This code gets "sourced" by a parent shell, and exiting causes the parent to quit. 



