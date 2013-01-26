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
##   Determine the parallel build type from the OS and configure option.
##
getParallelType()
{
   configOption=$1
   OS=`uname`
   parallelType='UNKNOWN'

   case $OS in
       AIX)
             case $configOption in
                 1)  parallelType='serial' 
		     ;;
                 2)  parallelType='openmp' 
		     ;;
                 3)  parallelType='mpi' 
		     ;;
             esac
             ;;
       Darwin)     
             # Assume Intel chipset for now
             case $configOption in
                 1|5|9|13|15|19)   parallelType='serial' 
		                   ;;
                 2|6|10|16)        parallelType='openmp' 
		                   ;;
                 3|7|11|14|17|20)  parallelType='mpi' 
		                   ;;
             esac
             ;;
       Linux)     
             # List for "configure" script depends on the chipset
	     OS=`uname -a`
	     # If return code from grep is zero, string was found
	     echo $OS | grep "x86_64" > /dev/null 2>&1
	     if [ $? == 0 ]; then
                 case $configOption in
                     1|5|9|13|17|21|23|27|31)   parallelType='serial' 
		                                ;;
                     2|6|10|14|18|24|28|32)     parallelType='openmp' 
		                                ;;
                     3|7|11|15|19|22|25|29|33)  parallelType='mpi' 
		                                ;;
                 esac
	     else
                 case $configOption in
                     1|5|9|11|15|19|23)   parallelType='serial' 
		                          ;;
                     2|6|10|12|16|20)     parallelType='openmp' 
		                          ;;
                     3|7|13|17|21|24)     parallelType='mpi' 
		                          ;;
                 esac
	     fi
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
         em_real|em_chem|em_chem_kpp)
                   PREPROCESSOR='real.exe' 
		   ;;
         em_b_wave|em_quarter_ss)
                   PREPROCESSOR='ideal.exe' 
		   ;;
         nmm_real|nmm_nest)
                   PREPROCESSOR='real_nmm.exe' 
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
   parallelType=$1
   test_dir=$2

   success=false

   case $parallelType in
      serial)  LOGFILE='wrf.out'
               ;;
      openmp)  LOGFILE='wrf.out'
               ;;
      mpi)     LOGFILE='rsl.error.0000'
               ;;
      *)       echo "$0::checkForecastResult():  unknown parallel type string."
               exit 2
   esac

   outputForm=`grep io_form_history $test_dir/namelist.input | cut -d '=' -f 2 | awk '{print $1;}`

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
          2) #NAN_REGEXP=" '[+-]?[Nn][Aa][Nn][Qq]?' "
             #ncdump $test_dir/wrfout_d01* | egrep -w $NAN_REGEXP  > /dev/null  2>&1
             #ncdump $test_dir/wrfout_d01* | egrep $NAN_REGEXP | grep -v description > /dev/null  2>&1
             ncdump $test_dir/wrfout_d01* | grep -i NaN | grep -v description > /dev/null  2>&1
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
      else
         # Log the reasons for forecast failure. 
         echo "$test_dir: FORECAST FAILURE: twosteps=$twoSteps, nonNaNs=$noNaNs, foundSuccess=$foundSuccess"
      fi
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

    # additional vars from "compile" script
    unset WRF_DA_CORE
    unset WRF_EM_CORE
    unset WRF_COAMPS_CORE
    unset WRF_EXP_CORE
    unset WRF_CONVERT
    unset WRF_SRC_ROOT_DIR
}


