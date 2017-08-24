#!/bin/ksh

## Common.ksh
##
##  Contains shell functions that are common across the scripts for building WRF, running tests,
##  and checking test results.
##
##  Author: Brian Bonnlander
##


##
##   Print a string surrounded by eye-catching format characters.
##
banner()
{
   printString=$1
   echo "\n###"
   echo   "###  $printString"
   echo   "###\n"
   return 0
}


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


##
##   Usage: name=`getParallelType $configure_option`
##
##   Determine the parallel build type from the OS and configure option.
##
getParallelType()
{
   set -x
   configOption=$1

   case $configOption in
         $CONFIGURE_SERIAL)  parallelType='serial' 
	                     ;;
         $CONFIGURE_OPENMP)  parallelType='openmp' 
	                     ;;
         $CONFIGURE_MPI)     parallelType='mpi' 
	                     ;;
         *)                  parallelType='UNKNOWN' 
	                     ;;
   esac
   echo $parallelType
}



##
##  Usage: name=`getPreprocessorName $wrf_type`
##
##  Returns the name of the preprocessor that gets built for a particular WRF type;
##  for example, returns "real_nmm.exe" for WRF type "nmm_real".  
##
getPreprocessorName() 
{
    wrfType=$1
    case $wrfType in 
         em_real|em_real8|em_move|em_chem|em_chem_kpp|wrfplus)
                   PREPROCESSOR='real.exe' 
		   ;;
         em_b_wave|em_quarter_ss|em_quarter_ss8|em_hill2d_x)
                   PREPROCESSOR='ideal.exe' 
		   ;;
         nmm_real|nmm_nest|nmm_hwrf)
                   PREPROCESSOR='real_nmm.exe' 
		   ;;
         wrfda_3dvar|wrfda_4dvar)
                   PREPROCESSOR='NONE'
                   ;;
         *)        echo "$0: Unknown WRF type: '$wrfType'"
                   exit 2
                   ;;
    esac
    echo $PREPROCESSOR
}       



##
## Usage:  fullPath=`makeFullPath $relPath $currDir`
##
##  Will check if the first argument is a full path; if not, it prepends the second argument.
##
makeFullPath()
{
   pathName=$1
   currDir=$2

   case $pathName in
         /*) fullPath=$pathName
	     ;;
         *) fullPath=${currDir}/${pathName}
	    ;;
   esac
   echo $fullPath
}




##
## Usage:  fileSuffix=`getFileSuffix $fileName`
##
##  Returns the substring appearing after the final '.' in a filename or path.
##
getFileSuffix()
{
   file=$1
   fileParts=`echo $file | tr '.' '\t'`
   suffix=`echo $fileParts | awk '{print $NF}'`
   echo $suffix
}



##
## Usage:  filePath=`getFilePath $fileName`
##
##  Given a full path to a file, return the directory portion 
##  (strip off the filename after the rightmost '/').
##
getFilePath()
{
   filePath=$1
   prefix=`dirname $filePath`
   echo $prefix
}



##
## Usage: `checkForecastResult $parallelType $test_dir` 
##
## Returns true if $test_dir exists and the test appears to have run to completion.
## Otherwise it returns false.
##
checkForecastResult()
{
   set -x
   parallelType=$1
   test_dir=$2

   success=false
   reason=""

   case $parallelType in
      serial)  LOGFILE='wrf.out'
               ;;
      openmp)  LOGFILE='wrf.out'
               ;;
      mpi)     LOGFILE='rsl.out.0000'
               ;;
      *)       echo "$0::checkForecastResult():  unknown parallel type string."
               exit 2
   esac

   outputForm=`grep io_form_history $test_dir/namelist.input | cut -d '=' -f 2 | awk '{print $1;}'`

   if [ -f $test_dir/wrfout_d01*  ]; then

      # Test for two timesteps in wrfout.
      case $outputForm in
          1) twoSteps="( 2 -eq 2 )"      # We don't have a way of checking number of steps with binary output
	     ;;    
          2) ncdump -h $test_dir/wrfout_d01_* | grep Time | grep currently | grep 2 > /dev/null  2>&1
             twoSteps="( $? -eq 0 )" 
	     ;;
          5) nSteps=`$test_dir/wgrib.exe -s -4yr $test_dir/wrfout_d01_* | grep ":UGRD:" | grep ":10 m" | wc -l`
             twoSteps="( $nSteps -eq 2 )" 
	     ;;
          *) echo "$0::checkForecastResult:  unknown WRF output format: $outputForm"
             exit 2
      esac

      # Test for no NaNs in wrfout.
      case $outputForm in
          1) noNaNs="( 1 -ne 0 )"      # We don't have a way of checking for NaNs with binary output
	     ;;
          2) ncdump $test_dir/wrfout_d01* | grep -i NaN | grep -v description > /dev/null  2>&1
             noNaNs="( $? -ne 0 )" 
	     ;;
          5) noNaNs="( 1 -ne 0 )"      # We don't have a way of checking for NaNs with Grib1 output
	     ;;
          *) echo "$0::checkForecast:  unknown WRF output format: $outputForm"
             exit 2
      esac

      # Test for "SUCCESS" in log file.
      grep "SUCCESS COMPLETE WRF" $test_dir/$LOGFILE > /dev/null  2>&1
      foundSuccess="( $? -eq 0 )"

      # Return true if all three conditions are met.
      if [ $twoSteps -a $noNaNs -a $foundSuccess ]; then
         success=true
      fi
      if [ ! $foundSuccess ]; then
         echo "Not found in WRF log file: 'SUCCESS COMPLETE WRF'." >> $test_dir/FAIL_FCST.tst
      fi
      if [ ! $noNaNs ]; then
         echo "NaN values found in wrfout file." >> $test_dir/FAIL_FCST.tst
      fi
      if [ ! $twoSteps ]; then
         echo "Number of timesteps in wrfout file did not equal two." >> $test_dir/FAIL_FCST.tst
      fi
   else
         echo "No wrfout file created." >> $test_dir/FAIL_FCST.tst
   fi
   echo $success
}



checkWRFPLUSResult()
{
   set -x
   parallelType=$1
   test_dir=$2

   success=false
   reason=""

   case $parallelType in
      serial)  LOGFILE='wrfplus.out'
               ;;
      openmp)  echo "WRFPLUS NOT SET UP FOR OPENMP. TEST SHOULD NEVER GET THIS FAR. BAD FAIL."
               exit 1
               ;;
      mpi)     LOGFILE='rsl.out.0000'
               ;;
      *)       echo "$0::checkWRFPLUSResult():  unknown parallel type string."
               exit 2
   esac

  #Perhaps later we can add checks to explicitly look at TL_CHECK and AD_CHECK results, 
  # but for now let's just look for a success message
   grep "SUCCESS COMPLETE WRF" $test_dir/$LOGFILE > /dev/null  2>&1
   foundSuccess="( $? -eq 0 )"

   if [ ! $foundSuccess ]; then
      echo "Not found in WRF log file: 'SUCCESS COMPLETE WRF'." >> $test_dir/FAIL_FCST.tst
   else
      success=true
   fi


   echo $success
}

##
## Usage: `checkDAResult $parallelType $test_dir`
##
## Same as "checkForecastResult" but for WRFDA tests
## Returns true if $test_dir exists and the test appears to have run to completion.
## Otherwise it returns false.
##
checkDAResult()
{
   set -x
   parallelType=$1
   test_dir=$2

   success=false
   reason=""

   case $parallelType in
      serial)  LOGFILE='wrfda.out'
               ;;
      openmp)  echo "WRFDA NOT SET UP FOR OPENMP. TEST SHOULD NEVER GET THIS FAR. BAD FAIL."
               exit 1
               ;;
      mpi)     LOGFILE='rsl.out.0000'
               ;;
      *)       echo "$0::checkDAResult():  unknown parallel type string."
               exit 2
   esac

   if [ -f $test_dir/wrfvar_output  ]; then

      # Test for non-zero cost function
      grep "Final cost function J" $test_dir/$LOGFILE | grep '[1-9]' > /dev/null  2>&1
      nonzeroCostFunction="( $? -eq 0 )"

      # Test for no NaNs in output
      ncdump $test_dir/wrfvar_output | grep -i NaN | grep -v description > /dev/null  2>&1
      noNaNs="( $? -ne 0 )"

      # Test for success message in log file.
      grep "WRF-Var completed successfully" $test_dir/$LOGFILE > /dev/null  2>&1
      foundSuccess="( $? -eq 0 )"

      # Return true if all three conditions are met.
      if [ $nonzeroCostFunction -a $noNaNs -a $foundSuccess ]; then
         success=true
      fi
      if [ ! $nonzeroCostFunction ]; then
         echo "Final cost function is zero." >> $test_dir/FAIL_FCST.tst
      fi
      if [ ! $foundSuccess ]; then
         echo "Not found in WRFDA log file: 'WRF-Var completed successfully'." >> $test_dir/FAIL_FCST.tst
      fi
      if [ ! $noNaNs ]; then
         echo "NaN values found in wrfvar_output file." >> $test_dir/FAIL_FCST.tst
      fi
   else
         echo "No wrfvar_output file created." >> $test_dir/FAIL_FCST.tst
   fi
   echo $success
}




##
## Usage: `wipeUserBuildVars` 
##
## Many users may already have an environment set up for building one kind of WRF.   
## This function removes any influence of pre-existing build settings for the 
## duration of the build process. 
##
wipeUserBuildVars()
{   
    # from "configure" script
    unset WRF_OS
    unset WRF_MACH
    unset WRF_CHEM
    unset WRF_HYDRO
    unset WRF_KPP 
    unset WRF_DFI_RADAR
    unset WRF_TITAN
    unset WRF_MARS
    unset WRF_VENUS
    unset WRFPLUS_DIR
    unset WRF_QUIETLY
    unset WRF_LOG_BUFFERING
    unset WRF_NMM_CORE
    unset HWRF
    unset WRFIO_NCD_LARGE_FILE_SUPPORT

    unset HDF5_PATH
    unset HDF5
    unset ZLIB_PATH
    unset GPFS_PATH
    unset CURL_PATH
    unset NETCDF4
    unset PNETCDF

    # additional vars from "compile" script
    unset WRF_DA_CORE
    unset WRF_EM_CORE
    unset WRF_COAMPS_CORE
    unset WRF_EXP_CORE
    unset WRF_CONVERT
    unset WRF_SRC_ROOT_DIR
 
    # these control how MPI jobs are run on Yellowstone
    unset MP_RESD
    unset MP_RMFILE
    unset MP_LLFILE
    unset MP_RMPOOL
}


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


# Returns true for a good combination of build parameters.  This may vary according to machine type, em_real vs. nmm,
#  or serial vs. parallel, for example. 
#
#  Bad parameter combinations include WRF-NMM or WRF-CHEM built with smpar (shared memory parallel).
#
#  usage:  GOOD=`goodConfiguration <wrf_type> <platform_choice>`
#
goodConfiguration()
{
   set -x
   wType=$1
   platf=$2

   # exclude OpenMP for nmm builds.
   if [ "$wType" = "nmm_real" -o "$wType" = "nmm_nest" -o "$wType" = "nmm_hwrf" ]; then
      if [ "$platf" = "openmp" ]; then
         echo false
         return 0
      fi
   # exclude OpenMP for chemistry builds.
   elif [ "$wType" = "em_chem" -o "$wType" = "em_chem_kpp" ]; then
      if [ "$platf" = "openmp" ]; then
         echo false
         return 0
      fi
   # exclude OpenMP for WRFDA builds.
   elif [ "$wType" = "wrfda_3dvar" -o "$wType" = "wrfda_4dvar" -o "$wType" = "wrfplus" ]; then
      if [ "$platf" = "openmp" ]; then
         echo false
         return 0
      fi
   # exclude OpenMP for 2d ideal builds.
   elif [ "$wType" = "em_hill2d_x" ]; then
      if [ "$platf" = "openmp" ]; then
         echo false
         return 0
      fi
   # exclude OpenMP for ARW moving nest.
   elif [ "$wType" = "em_move" ]; then
      if [ "$platf" = "openmp" ]; then
         echo false
         return 0
      fi
   fi

   # exclude Serial for ARW moving nest.
   if [ "$wType" = "em_move" ]; then
      if [ "$platf" = "serial" ]; then
         echo false
         return 0
      fi
   fi
   # exclude Serial for nmm_hwrf builds.
   if [ "$wType" = "nmm_hwrf"  ]; then
      if [ "$platf" = "serial" ]; then
         echo false
         return 0
      fi
   fi

   # exclude MPI for 2d ideal builds.
   if [ "$wType" = "em_hill2d_x"  ]; then
      if [ "$platf" = "mpi" ]; then
         echo false
         return 0
      fi
   fi

   echo true
   return 0
}


#
#  Waits for all batch jobs matching a given string to finish.
#  Only call this function if you are running batch jobs.
#  The first parameter indicates the type of batch queue manager used.
#  The second parameter is the string to match to job names
#  The third parameter is the wait time in seconds between checks
#
#  NOTE: job string must escape special characters like ".", i.e. "\."
#
#  usage: batchWait <LSF_PBS_NSQ> <jobstring> waitTime 
#   
batchWait()
{
   queueType=$1
   jobString=$2
   waitTime=$3

   case $queueType in
      LSF)   JOBS=`bjobs -w | grep $jobString`
             while [ -n "$JOBS" ]; do
                  sleep $waitTime
                  JOBS=`bjobs -w | grep $jobString`
             done
             ;;
      PBS)   userName=`whoami`
             JOBS=`qstat -u $userName | grep $userName | grep $jobString`
             while [ -n "$JOBS" ]; do
                  sleep 60
                  JOBS=`qstat -u $userName | grep $userName | grep $jobString`
                  echo JOBS="$JOBS"
             done
             ;;
      NQS)   userName=`whoami`
             JOBS=`qstat -u $userName | grep $userName | grep $jobString | awk '{print $10}' | grep -v C`
             while [ -n "$JOBS" ]; do
                  sleep $waitTime
                  JOBS=`qstat -u $userName | grep $userName | grep $jobString | awk '{print $10}' | grep -v C`
                  echo JOBS="$JOBS"
             done
             ;;
   esac
}

