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
       nmm_hwrf)       typeCode='nh'
                       ;;
       em_chem)        typeCode='ec'
                       ;;
       em_chem_kpp)    typeCode='ek'
                       ;;
       em_b_wave)      typeCode='eb'
                       ;;
       em_quarter_ss)  typeCode='eq'
                       ;;
       em_hill2d_x)    typeCode='eh'
                       ;;
       em_move)        typeCode='em'
                       ;;
       wrfda_3dvar)    typeCode='3d'
                       ;;
       wrfplus)        typeCode='wp'
                       ;;
       wrfda_4dvar)    typeCode='4d'
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

# Special case for WRFDA 4DVAR test: need to compile wrfplus, then 4dvar
#BUILD_TYPES=$(echo $BUILD_TYPES | sed 's/wrfda_4dvar/wrfplus wrfda_4dvar/g')
#NEVERMIND, RELY ON USER TO DO THIS

if $BATCH_COMPILE; then
    ## From the user-specified list of WRF executables, create two lists: those that can be built in parallel, 
    ## and those that must be built consecutively.   
    WRF_PARALLEL=""
    WRF_SERIAL=""
    for f in $BUILD_TYPES; do
       case $f in 
           em_real|em_hill2d_x|em_move|nmm_real|nmm_nest|nmm_hwrf|em_chem|em_chem_kpp|wrfda_3dvar|wrfplus) WRF_PARALLEL="$WRF_PARALLEL $f"
	                                                  ;;
           em_b_wave|em_quarter_ss|wrfda_4dvar)           WRF_SERIAL="$WRF_SERIAL $f"
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
   # The "ni" option is the type of nesting.  The default is "1" - standard nesting.  The hill2d case is
   # built with "0" (i.e. without nesting, which is actually the entire purpose for including this ideal case in the mix).  The
   # ARW moving nest case is vortex following, and requires the nest option to be "3".
   for platform in $CONFIGURE_CHOICES; do
      buildDir=${BUILD_DIR}/$wrfTarName.$platform
      buildString=`getBuildString $wrfType $platform`
      if $BATCH_COMPILE; then
         if [[ $wrfType = "em_hill2d_x" ]]; then 
            $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD -ni 0 &
         elif [[ $wrfType = "em_move" ]]; then 
            $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD -ni 3 &
         else
            $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD &
         fi
      else
         if [[ $wrfType = "em_hill2d_x" ]]; then 
            $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD -ni 0 
         elif [[ $wrfType = "em_move" ]]; then 
            $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD -ni 3 
         else
            $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD
         fi
      fi
   done
done


# 
#  Make sure all batch jobs have been submitted, then wait for them to finish.
# 

wait
if $BATCH_COMPILE; then
   batchWait $BATCH_QUEUE_TYPE 'bld\.'
fi

# Then, when all the above builds have finished, fire off the builds that cannot
# be run in parallel.   These should complete quickly, since they re-use prior WRF builds.

wait

# Loop over WRF flavors (e.g. em_b_wave, nmm_nest, etc.)
for wrfType in $WRF_SERIAL; do
   # Loop over parallel build choices for this WRF type (e.g. serial, openmp, mpi). 
   for platform in $CONFIGURE_CHOICES; do
      buildDir=${BUILD_DIR}/$wrfTarName.$platform
      buildString=`getBuildString $wrfType $platform`
      if $BATCH_COMPILE; then
         $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD &
      else
         $WRF_TEST_ROOT/scripts/buildWrf.ksh -f $TARFILE -d $buildDir -ci $platform -ct $wrfType -bs $buildString -N $NUM_PROC_BUILD 
      fi
   done
   # Wait for builds in each separate build space to finish.
   wait
   if $BATCH_COMPILE; then
      batchWait $BATCH_QUEUE_TYPE 'bld\.'
   fi
done

echo ALL BUILDS APPEAR TO BE DONE!
date

#  Do not exit!   This code gets "sourced" by a parent shell, and exiting causes the parent to quit. 


