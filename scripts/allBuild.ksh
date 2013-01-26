#!/bin/ksh

## allBuild.ksh
##
##  Given a WRF tarfile and target directory, this script builds WRF for various platform 
##    platforms (serial, smpar, dmpar) and build types (em_real, nmm_real, em_b_wave, em_quarter_ss). 
##
##  Author: Brian Bonnlander
##

#  Returns a short string to identify with the build job.  This is 
#  used at the end of the script to keep the script from exiting until
#  all builds have completed. 
getBuildString()
{
    wrfType=$1
    config_id=$2
    case $wrfType in
       em_real)        typeCode='er'
                       ;;
       nmm_real)       typeCode='nr'
                       ;;
       nmm_nest)       typeCode='nn'
                       ;;
       em_chem)        typeCode='ec'
                       ;;
       em_chem_kpp)    typeCode='ek'
                       ;;
       em_b_wave)      typeCode='eb'
                       ;;
       em_quarter_ss)  typeCode='eq'
                       ;;
                   *)  echo $0:getBuildString:  unknown wrfType $wrfType
                       exit 2
                       ;;
     esac
     echo "bld.${typeCode}.${config_id}"
}


if $DEBUG_WTF; then
   set -x
fi


if $BATCH_COMPILE; then
    ## From the user-specified list of WRF executables, create two lists: those that can be built in parallel, 
    ## and those that must be built consecutively.   
    WRF_PARALLEL=""
    WRF_SERIAL=""
    for f in $BUILD_TYPES; do
       case $f in 
           em_real|nmm_real|nmm_nest|em_chem|em_chem_kpp) WRF_PARALLEL="$WRF_PARALLEL $f"
	                                                  ;;
           em_b_wave|em_quarter_ss)                       WRF_SERIAL="$WRF_SERIAL $f"
	                                                  ;;
           *) echo "$0: unknown executable type: '$f'; aborting!"
              exit 255
       esac
    done 
else
    WRF_PARALLEL=""
    WRF_SERIAL=$BUILD_TYPES
fi


wrfTarName=`basename $TARFILE .tar`

# First, fire off the builds that can be done in parallel.
for wrfType in $WRF_PARALLEL; do

   # Loop over platform choices for this WRF type. 
   for platform in $CONFIGURE_CHOICES; do
      buildDir=${BUILD_DIR}/$wrfTarName.$platform
      buildString=`getBuildString $wrfType $platform`
      if $BATCH_COMPILE; then
         $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD &
      else
         $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD
      fi
   done
done


# 
#  The "batch wait" code below is copy-pasted from the bottom of this script.  It should probably be put in a function 
#  to eliminate duplicate code. 
# 

wait
if $BATCH_COMPILE; then
    OS_NAME=`uname`
    case $BATCH_QUEUE_TYPE in
       LSF)   JOBS=`bjobs -w | grep bld\.`
              while [ -n "$JOBS" ]; do
                   sleep 60
                   JOBS=`bjobs -w | grep bld\.`
              done
	      ;;
       NQS) JOBS=`qstat -u bonnland | grep bonnland | grep 'bld' | awk '{print $10}' | grep -v C`
              while [ -n "$JOBS" ]; do
                   sleep 60
                   JOBS=`qstat -u bonnland | grep bonnland | grep 'bld' | awk '{print $10}' | grep -v C`
                   echo JOBS="$JOBS"
              done
	      ;;
    esac
fi

# Then, when all the above builds have finished, fire off the builds that cannot
# be run in parallel.   These should complete quickly, since they re-use prior WRF builds.

wait

for wrfType in $WRF_SERIAL; do
   # Loop over platform choices for this WRF type. 
   for platform in $CONFIGURE_CHOICES; do
      buildDir=${BUILD_DIR}/$wrfTarName.$platform
      buildString=`getBuildString $wrfType $platform`
      $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD 
   done
done


# Now we keep this script alive until all builds are done.   This will let us string together
# this script with another than runs all the tests.  If builds are not done using batch queues, then we reach this 
# point only after all builds are done (thanks to "wait").   So we only worry about batch cases now. 

if $BATCH_COMPILE; then
    OS_NAME=`uname`
    case $BATCH_QUEUE_TYPE in
       LSF)   JOBS=`bjobs -w | grep bld\.`
              while [ -n "$JOBS" ]; do
                   sleep 60
                   JOBS=`bjobs -w | grep bld\.`
              done
	      ;;
       NQS) JOBS=`qstat -u bonnland | grep bonnland | grep 'bld' | awk '{print $10}' | grep -v C`
              while [ -n "$JOBS" ]; do
                   sleep 60
                   JOBS=`qstat -u bonnland | grep bonnland | grep 'bld' | awk '{print $10}' | grep -v C`
                   echo JOBS="$JOBS"
              done
	      ;;
    esac
fi

echo ALL BUILDS APPEAR TO BE DONE!
date

#  Do not exit!   This code gets "sourced" by a parent shell, and exiting causes the parent to quit. 


