#!/bin/ksh


## buildWrf.ksh
##
##  Unpacks and builds the WRF code: produces a wrf.exe executable and a pre_wrf*.exe preprocessor.   
##  If the two target executables already exist, then nothing is done. 
##  
##  Author: Brian Bonnlander
##

if $DEBUG_WTF; then
   set -x
fi

# Include common functions.
. $WRF_TEST_ROOT/scripts/Common.ksh


##  Script should take the following params: tar file, build directory, configure option, nesting option, 
##    compile string (em_real, nmm_real, etc). , real*4 vs. real*8, etc.  

usage()
{
   echo >&2 "usage: $0 -f <tar_file> -d <build_dir> -ci <configure_choice> -ct <compile_type> -bs <build_string> [-ni <nesting_choice>] [-v] [-r8] [-N <#procs>]"
   echo >&2 "   (configure and nesting choices must be integers; -r8 sets double precision calculations; -v for verbose)"
   echo >&2 "   (-N <#nprocs> specifies the number of processors per build; default is 1)"
   echo >&2 "   (<compile_type> can be one of: {em_real, em_b_wave, em_quarter_ss, nmm_real, nmm_nest})"
}



#  usage:  USABLE=`reusable_wrfdir <dir>`   
# returns true if given directory can be re-used for building a different version of WRF or WRF preprocessor. 
reusable_wrfdir()
{
  wrfdir=$1
  if [ -d $wrfdir ]; then
     OLD_REAL8=false
     if [ -f $wrfdir/REAL8 ]; then
        OLD_REAL8=true
     fi
     if [[ $REAL8 == $OLD_REAL8 ]]; then
        if [ -f $wrfdir/main/wrf.exe ]; then
           echo true
	   return 0
        fi
     fi
  fi
  echo false
  return 0
}




##
##  Default values for command-line options.  
##

tarFile=''           #  Path to the WRF distribution tarfile. 
buildDir=''          #  Directory where the tarfile will be unpacked and built.
CONFIG_OPTION=''      #  Integer selecting which WRF platform to build in the 'configure' script.
COMPILE_TYPE=''       #  Which version of WRF to build (em_real, nmm_real, etc.).
BUILD_STRING=''       #  Unique string attached to batch job; used to test when builds are all complete

NEST_OPTION=1         #  Integer selecting which nesting option to enable in the WRF build; default is 1 (basic nesting).
REAL8=false           #  Whether floating point calcs should be double-precision; default is false.
NUM_PROCS=1           #  Number of processors to use per WRF build.


##
## Flags/variables used for controlling build logic.
##  

UNPACK_WRF=true
RUN_CONFIGURE=true
RUN_COMPILE=true


##
## Parse command line and set variables. 
##

CURRENT_DIR=`pwd`

while [ $# -gt 0 ]
do
    case "$1" in
        -f)   shift;  tarFile=$1       ;;
        -d)   shift;  buildDir=$1      ;;
        -ci)  shift;  CONFIG_OPTION=$1 ;;
        -ct)  shift;  COMPILE_TYPE=$1  ;;
        -ni)  shift;  NEST_OPTION=$1   ;;
        -bs)  shift;  BUILD_STRING=$1  ;;
        -N)   shift;  NUM_PROCS=$1     ;;
        -r8)          REAL8=true       ;;
	*)  usage
	    exit 1
    esac
    shift
done


##
## Exit if any required variable is not set.
##

if [[ -z $tarFile ]]      || [[ -z $buildDir ]] ||
   [[ -z $CONFIG_OPTION ]] || [[ -z $COMPILE_TYPE ]] || [[ -z $BUILD_STRING ]]; then
   usage
   exit 1
fi


##
## Verify that configure/nesting options are integers, and compile string is valid.
##

case $CONFIG_OPTION in 
    [0-9]|[0-9][0-9])    # Do nothing if we have an integer
        ;; 
    *)  echo $0: configure option '$CONFIG_OPTION' is not an integer; stopping.
        exit 1 ;;
esac

case $NEST_OPTION in 
    [0-9])    # Do nothing if we have an integer
        ;; 
    *)  echo $0: nesting option '$NEST_OPTION' is not an integer; stopping.
        exit 1 
	;;
esac


##
## Clear any pre-existing build variables that the user may have set
## (just for this script)
##

wipeUserBuildVars


##
## Set specific build variables for different versions of WRF.  
##

# In most cases, $COMPILE_TYPE is the string passed to the "compile" command.  
# The exceptions are "nmm_nest","em_chem", and "em_chem_kpp". 
COMPILE_STRING=$COMPILE_TYPE

if $OPTIMIZE_WRF; then
    CONFIGURE_COMMAND="./configure"
else
    CONFIGURE_COMMAND="./configure -d"
fi


PREPROCESSOR=`getPreprocessorName $COMPILE_STRING`
wallTime="0:90"

case $COMPILE_STRING in
    em_real)       
                   COMPATIBLE_BUILD='em_real'
                   ;;
    em_b_wave|em_quarter_ss)
                   COMPATIBLE_BUILD='em_real'
                   wallTime="0:10"
                   ;;
    nmm_real)
                   COMPATIBLE_BUILD='nmm_real'
                   export WRF_EM_CORE=0
                   export WRF_NMM_CORE=1
                   export WRF_NMM_NEST=0
                   ;;
    nmm_nest)
		   COMPILE_STRING='nmm_real'    # For nmm_nest, "compile nmm_real" is needed. 
                   NEST_OPTION=1
                   COMPATIBLE_BUILD='nmm_nest'
                   export WRF_EM_CORE=0
                   export WRF_NMM_CORE=1
                   export WRF_NMM_NEST=1
                   ;;
    em_chem)
		   COMPILE_STRING='em_real'    # For chemistry, "compile em_real" is needed. 
                   COMPATIBLE_BUILD='em_chem'
		   export WRF_CHEM=1
		   export WRF_KPP=0
		   export CHEM_OPT=''
		   if [ $OPTIMIZE_WRF_CHEM = false ]; then
		       CONFIGURE_COMMAND="./configure -d "
		   fi 
		   ;;
    em_chem_kpp)
		   COMPILE_STRING='em_real'    # For KPP chemistry, "compile em_real" is needed. 
                   COMPATIBLE_BUILD='em_chem_kpp'
		   export WRF_CHEM=1
		   export WRF_KPP=1
		   export YACC='/usr/bin/yacc -d'
		   export CHEM_OPT=104
		   if [ $OPTIMIZE_WRF_CHEM = false ]; then
		       CONFIGURE_COMMAND="./configure -d "
		   fi 
		   ;;
    *)             echo "$0: Unknown compile string: '$COMPILE_TYPE'"
                   exit 2
                   ;;
esac

##
## Verify existence of files and directories.
##

# tarFile must point to an existing file.  
if [ ! -f $tarFile ]; then
   echo "$0: nonexistent tar file: '${tarFile}'; stopping."
   exit 2
fi

# tarFile must be an actual tarfile. 
#topDir=`tar tf $tarFile | head -1`
(tar -tf $tarFile | head -1) > /tmp/.foo_$$ 2> /dev/null
topDir=`cat /tmp/.foo_$$`
topDir=`basename $topDir`
\rm /tmp/.foo_$$

if [ -z $topDir ]; then
   echo "$0: not a valid tarfile: '${tarFile}'; stopping."
   echo "Rebuild the tarfile so it unpacks everything into a directory 'WRFV3'."
   exit 2
fi


targetDir=${buildDir}/${COMPILE_TYPE}/${topDir}
REUSE_DIR=${buildDir}/${COMPATIBLE_BUILD}/${topDir}
TARGET_PREWRF=prewrf_${COMPILE_TYPE}.exe


## Make sure we have a valid build configuration.  This may depend on the machine, WRF flavor, or
##   platform choice.   
##   
##   Exit with an informational message if this is not a valid build configuration. 

parallelType=`getParallelType $CONFIG_OPTION`
goodConfig=`goodConfiguration $COMPILE_TYPE $parallelType`
if ( ! $goodConfig ); then
   banner  "Bad build combo; skipping WRF build $COMPILE_TYPE for platform choice $CONFIG_OPTION ...."
   exit 0
fi

banner "Building WRF $COMPILE_TYPE, option $CONFIG_OPTION in $buildDir .... "


## Decide whether we have already built the target executables; if not, decide if we have
## available an existing build directory, a re-usable directory, or 
## we are unpacking from a tar file.   In the first two cases, we check that settings are 
## compatible and that a successful wrf.exe was built. 

USABLE_TARGET_DIR=`reusable_wrfdir $targetDir`
USABLE_REUSE_DIR=`reusable_wrfdir $REUSE_DIR`

if [ -d $targetDir ]; then
       if [ -f $targetDir/main/wrf.exe -a -f $targetDir/main/$TARGET_PREWRF ]; then
          echo "Both target executables already exist for $targetDir; nothing to be done."
          exit 0
       fi
       if [ -f $targetDir/SUCCESS_TAR.tst ]; then
          UNPACK_WRF=false
       fi
       if [ -f $targetDir/configure.wrf ]; then
          RUN_CONFIGURE=false
       fi

elif [ -d $REUSE_DIR -a -f $REUSE_DIR/SUCCESS_TAR.tst ]; then
   if $USABLE_REUSE_DIR; then
       echo "Linking to reusable directory $REUSE_DIR"
       mkdir -p $buildDir/$COMPILE_TYPE
       if [ $? != 0 ]; then
          echo $0: unable to create directory $buildDir/$COMPILE_TYPE; exiting.
          exit 2
       fi
       ln -s $REUSE_DIR $buildDir/$COMPILE_TYPE
       UNPACK_WRF=false
       RUN_CONFIGURE=false
   else
       echo "Existing build directory unusable; delete directory and retry script: $targetDir"
       exit 2
   fi
fi

echo "### UNPACK_WRF = $UNPACK_WRF"
echo "### REAL8 = $REAL8"

# Unpack the WRF tar file if needed.  Record the REAL8 setting by touching a file. 
if $UNPACK_WRF; then
   ##
   ##  Untar WRF code. 
   ## 

   mkdir -p $buildDir/$COMPILE_TYPE
   if [ $? != 0 ]; then
      echo "$0: Unable to create target build directory '$buildDir/$COMPILE_TYPE'; stopping."
      exit 2
   fi
   #date > $buildDir/StartTime_${COMPILE_TYPE}.txt

   oldDir=`pwd`
   cd $buildDir/$COMPILE_TYPE 
   tar -xf $tarFile
   tarSuccess=$?
   if [ $? != 0 ]; then
      echo "$0: Unable to untar '${tarFile}' in '$buildDir/$COMPILE_TYPE'; stopping."
      exit 2
   fi
   # Run "clean -a" on untarred source, in case it wasn't clean when tarred up.
   cd $targetDir
   ./clean -a
   cd $oldDir

   # Indicate that untarring was a success and does not need to be repeated again. 
   if [ $tarSuccess == 0 ]; then
      touch $targetDir/SUCCESS_TAR.tst
   fi

   # Record the REAL8 setting that will be used for compilation.
   if $REAL8; then
      echo "REAL8==$REAL8; touching REAL8 file."
      touch $targetDir/REAL8
   else
      echo "REAL8==$REAL8; touching REAL4 file."
      touch $targetDir/REAL4
   fi 
fi

cd $targetDir

echo "### RUN_CONFIGURE = $RUN_CONFIGURE"

if $RUN_CONFIGURE; then

# Put interactive "configure" options in a file, then pass to configure.
cat > $targetDir/CONFIG_OPTIONS << EOF
$CONFIG_OPTION
$NEST_OPTION
EOF

    # Run 'configure' and provide choices using shell "Here document" syntax.   Check exit status before continuing.
    #./configure < $targetDir/CONFIG_OPTIONS
    echo CONFIGURE_COMMAND==$CONFIGURE_COMMAND   # Diagnostic; remove once command works correctly.
    $CONFIGURE_COMMAND < $targetDir/CONFIG_OPTIONS

    cp configure.wrf configure.wrf.core=${COMPILE_TYPE}_build=${CONFIG_OPTION}
    
    #       The configure.wrf file needs to be adjusted as to whether we are requesting real*4 or real*8
    #       as the default floating precision.
    
    if $REAL8; then
        #sed -e '/^RWORDSIZE/s/\$(NATIVE_RWORDSIZE)/8/'  configure.wrf > ! foo ; /bin/mv foo configure.wrf
        sed -e '/^RWORDSIZE/s/\$(NATIVE_RWORDSIZE)/8/'  configure.wrf > foo ; /bin/mv foo configure.wrf
    fi
    
fi 

echo "### RUN_COMPILE = $RUN_COMPILE"

OS_NAME=`uname`

#if [ `hostname | cut -c1-2` == "ys" ]; then
#   echo "YELLOWSTONE!"
#   BATCH_COMPILE=false
#fi


# Run 'compile'; see existing regression scripts.    
if $RUN_COMPILE; then
   
   echo BATCH_COMPILE==$BATCH_COMPILE
   if $BATCH_COMPILE; then
       case $BATCH_QUEUE_TYPE in
          LSF)  BSUB="bsub -K -q $BUILD_QUEUE -P $BATCH_ACCOUNT -n $NUM_PROCS -a poe -W $wallTime -J $BUILD_STRING -o build.out -e build.err -cwd $targetDir "
                ;;
          NQS)  export MSUBQUERYINTERVAL=30
                export PNETCDF="/curc/tools/free/redhat_5_x86_64/parallel-netcdf-1.2.0_openmpi-1.4.5_intel-12.1.4/"
                BSUB="msub -K -V -q janus-debug -l nodes=1:ppn=$NUM_PROCS,walltime=${wallTime}:00 -N $BUILD_STRING -o $targetDir/build.out -e $targetDir/build.err -d $targetDir "
                ;;
          *)    echo "$0: unknown BATCH_QUEUE_TYPE '$BATCH_QUEUE_TYPE'; aborting!"
                exit 3
       esac

       # Put num processors and "compile" command in a file, then submit as a batch job. 
       cat > $targetDir/build.sh << EOF
          export J="-j ${NUM_PROCS}"
          date > StartTime_${COMPILE_TYPE}.txt
          \rm -f *COMPILE.tst   # Remove previous compile test results
          ./compile $COMPILE_STRING > compile_${COMPILE_STRING}.log 2>&1
          date > EndTime_${COMPILE_TYPE}.txt
EOF
       echo $BSUB > $targetDir/submitCommand
       $BSUB < $targetDir/build.sh
   else
      date > StartTime_${COMPILE_TYPE}.txt
      \rm -f *COMPILE.tst   # Remove previous compile test results
      ./compile $COMPILE_STRING > compile_${COMPILE_STRING}.log 2>&1
      date > EndTime_${COMPILE_TYPE}.txt
   fi 
   
   # Success means both wrf.exe and $PREPROCESSOR were created.
   if [ -f  $targetDir/main/wrf.exe -a -f $targetDir/main/$PREPROCESSOR ]; then
         touch $targetDir/SUCCESS_COMPILE.tst
   else
      touch $targetDir/FAIL_COMPILE.tst
      echo $0: compile failed to create wrf.exe and $PREPROCESSOR in $targetDir/main!
      exit 2
   fi

fi


# Rename WRF preprocessing executable (real.exe/ideal.exe) to a consistently named file.
PREPROCESSOR=$targetDir/main/$PREPROCESSOR
TARGET_PREWRF=$targetDir/main/$TARGET_PREWRF

echo PREPROCESSOR=$PREPROCESSOR
echo TARGET_PREWRF=$TARGET_PREWRF

\mv -f $PREPROCESSOR $TARGET_PREWRF


# Success; exit with no error. 

exit 0


