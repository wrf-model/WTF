#!/bin/ksh

## testWrf.ksh
##
##  Builds a test directory for a particular namelist file and WRF build, then runs both 
##  "real" and "wrf" in that test directory.  
##
##  NOTE: unless -C is specified, tests will not be re-performed if a successful forecast already exists
##        in a test directory. 
##  
##  Author: Brian Bonnlander
##

if $DEBUG_WTF; then
   set -x
fi

# Include common functions
.  $WRF_TEST_ROOT/scripts/Common.ksh


usage(){
   echo >&2 "usage: $0 [-G BATCH_ACCOUNT] [-C] -d <test_dir> -t <wrf_root_dir> -m <regdata_dir> -n <namelist_path> -par <parallel_type> -wt <wrf_type> "
   echo >&2 ""
   echo >&2 "   (-G BATCH_ACCOUNT uses the given account number/string for mpi and openmp runs.)"
   echo >&2 "   (specifying -C will 'clobber' a test that may have been done in the past.)"
   echo >&2 "   (<parallel_type> is one of the strings in {serial, openmp, mpi}.)"
   echo >&2 "   (<wrf_type> is one of the strings in {em_real, em_real8, em_move, em_hill2d_x, em_b_wave, em_quarter_ss, em_quarter_ss8, nmm_real, nmm_nest}.)"
}




##
## getTableNames():
##    Searches the top-level WRF Makefile to create a list of WRF tables for linking into the test directory.
##
getTableNames()
{
   wrfType=$1
   # grep in the Makefile for 'ln -s' commands, remove non-table names, split lines into individual commands.
   # for 8-bit executables, we need the "DBL" tables
   if [[ $WRF_TYPE = "wrfda_3dvar" || $WRF_TYPE = "wrfda_4dvar" || $WRF_TYPE = "wrfplus" || $WRF_TYPE = "em_real8" ]]; then
      WRF_TABLES=`grep 'ln -s' ${WRF_ROOT_DIR}/Makefile | egrep -v '=|input|namelist|.exe' | tr ";" "\n" | grep 'ln -s' | awk '{print $3}' | sort -u`
   else
      WRF_TABLES=`grep 'ln -s' ${WRF_ROOT_DIR}/Makefile | egrep -v '=|input|DBL|namelist|.exe' | tr ";" "\n" | grep 'ln -s' | awk '{print $3}' | sort -u`
   fi
   TABLE_NAMES=''
   # Now isolate just the filenames from their parent directory pathnames. 
   for f in `echo $WRF_TABLES`; do
      name=`basename $f`
      echo $name
      TABLE_NAMES=`echo $TABLE_NAMES $name`
   done

   # Send names to stdout, where they can be captured by invoking function with `getTableNames`.
   echo $TABLE_NAMES
}




##
## Usage: jobString=`getJobString $wrfType $parallelType $namelistPath`
##
##  Returns a string identifier for this test to give to BSUB.
##
getJobString()
{
   wrfType=$1
   parallelType=$2
   nlFile=$3
   nlSuffix=`getFileSuffix $nlFile`

   case $wrfType in
        em_real)         part1='er'   ;;
        em_real8)        part1='eR'   ;;
        em_b_wave)       part1='eb'   ;;
        em_quarter_ss)   part1='eq'   ;;
        em_quarter_ss8)  part1='eQ'   ;;
        em_hill2d_x)     part1='eh'   ;;
        em_move)         part1='em'   ;;
        em_chem)         part1='ec'   ;;
        em_chem_kpp)     part1='ek'   ;;
        nmm_real)        part1='nr'   ;;
        nmm_nest)        part1='nn'   ;;
        nmm_hwrf)        part1='nh'   ;;
        wrfda_3dvar)     part1='3d'   ;;
        wrfplus)         part1='wp'   ;;
        wrfda_4dvar)     part1='4d'   ;;
        *)               echo "$0::getJobString: unknown wrfType '$wrfType'"
                         exit 2
   esac

   case $parallelType in
        serial)   part2='se'   ;;
        openmp)   part2='sm'   ;;
        mpi)      part2='dm'   ;;
        *)        echo "$0::getJobString: unknown parallelType '$parallelType'"
                  exit 2
   esac

   echo "t.${part1}.${part2}.${nlSuffix}"
}




##
##  Initialize command-line variables.  
##

testDir=''        #  The directory where the test will be run
WRF_ROOT_DIR=''   #  The directory where WRF run-time tables are located
REGDATA_PATH=''   #  The directory containing all regression data files for this test
NAMELIST_PATH=''  #  The path to the namelist file 
BATCH_ACCOUNT=''  #  The account number or string to use for a batch-submitted openmp or mpi test
PARALLEL_TYPE=''  #  Should be 'serial', 'openmp', or 'mpi' 
WRF_TYPE=''       #  Should be one of 'em_real', 'em_b_wave', 'nmm_real', etc.
CLOBBER=false     #  If true, pre-existing test results are potentially lost and test is run again.


##
## Parse command line and set variables. 
##

CURRENT_DIR=`pwd`

while [ $# -gt 0 ]
do
    case "$1" in
        -G)  shift;  BATCH_ACCOUNT=$1   ;;
        -d)  shift;  testDir=$1         ;;
        -t)  shift;  WRF_ROOT_DIR=$1    ;;
        -m)  shift;  REGDATA_PATH=$1    ;;
        -n)  shift;  NAMELIST_PATH=$1   ;;
        -par)shift;  PARALLEL_TYPE=$1   ;;
        -wt) shift;  WRF_TYPE=$1        ;;
        -C)          CLOBBER=true       ;;
        *)  usage
            exit 1
    esac
    shift
done


##
## Exit if any required parameter is not given.
##

if [[ -z $testDir ]]      || [[ -z $WRF_ROOT_DIR ]] ||
   [[ -z $REGDATA_PATH ]]  || [[ -z $NAMELIST_PATH ]] ||
   [[ -z $PARALLEL_TYPE ]]  || [[ -z $WRF_TYPE ]] || 
   [[ -z $BATCH_ACCOUNT ]]; then 
   usage
   exit 1
fi

##
## Verify existence of directories and files.  
##

OS_NAME=`uname`


# WRF root directory must exist, top-level Makefile must exist, test/em_real directory must exist.
if [[ ! -d $WRF_ROOT_DIR ]] || [[ ! -f $WRF_ROOT_DIR/Makefile ]] || [[ ! -d $WRF_ROOT_DIR/test/em_real ]]; then
   echo "WRF source root directory '${WRF_ROOT_DIR}' not found or missing files; exiting."
   exit 2
fi

# Namelist file must exist and have nonzero size. 
if [[ ! -e $NAMELIST_PATH ]] || [[ ! -s $NAMELIST_PATH ]]; then
   echo "Namelist file '${NAMELIST_PATH}' not found or has zero size; exiting."
   exit 2
fi

# Regression data directory must exist. 
REGDATA_FILES=''
if [[ ! -d $REGDATA_PATH ]]; then
   echo "Regression data directory does not exist; exiting: '${REGDATA_PATH}'"
   exit 2
fi

REGDATA_FILES=`ls ${REGDATA_PATH}/*`

case $PARALLEL_TYPE in
   serial) SERIAL_QUEUE=`grep SERIAL_QUEUE ${NAMELIST_PATH} | cut -d '=' -f 2`
           if [ -z "$SERIAL_QUEUE" ]; then
              BATCH_QUEUE=$TEST_QUEUE
           else
              BATCH_QUEUE=$SERIAL_QUEUE
           fi
           ;;
   openmp) OPENMP_QUEUE=`grep OPENMP_QUEUE ${NAMELIST_PATH} | cut -d '=' -f 2`
           if [ -z "$OPENMP_QUEUE" ]; then
              BATCH_QUEUE=$TEST_QUEUE
           else
              BATCH_QUEUE=$OPENMP_QUEUE
           fi
           ;;
   mpi)    MPI_QUEUE=`grep MPI_QUEUE ${NAMELIST_PATH} | cut -d '=' -f 2`
           if [ -z "$MPI_QUEUE" ]; then
              BATCH_QUEUE=$TEST_QUEUE
           else
              BATCH_QUEUE=$MPI_QUEUE
           fi
           ;;
   *) echo "$0: Error, unknown parallel setting ${PARALLEL_TYPE}."
      exit 3
   esac

# Set the number of processors/threads to use for the test.
if [ "$BATCH_COMPILE" = false -a "$BATCH_TEST" = false ]; then
   NUM_PROC=$NUM_PROC_TEST
else
   NUM_PROC=`grep NUM_PROCESSORS ${NAMELIST_PATH} | cut -d '=' -f 2`
   if [ -z "$NUM_PROC" ]; then
      if [[ $BATCH_QUEUE = "share" ]] || [[ $BATCH_QUEUE = "caldera" ]]; then
         NUM_PROC=$NUM_PROC_TEST
      else
         case $BATCH_QUEUE_TYPE in
            LSF) NUM_PROC="32"
                 ;;
            PBS) NUM_PROC="36"
                 ;;
            *)   NUM_PROC="16"
                 ;;
         esac
      fi
   fi
fi

BATCH_MEM=`grep MEMORY_REQ ${NAMELIST_PATH} | cut -d '=' -f 2`
if [ -z "$BATCH_MEM" ]; then
   BATCH_MEM=$MEM_TEST
fi

# Set MPI command out here to make smaller case statements

if $BATCH_TEST; then
   case $BATCH_QUEUE_TYPE in
      LSF) MPI_CMD="mpirun.lsf"
           ;;
      PBS) if [[ $BATCH_QUEUE = "share" ]] then
              MPI_CMD="mpirun \`hostname\` -np $NUM_PROC"
           else
              MPI_CMD="mpiexec_mpt omplace -vv"
           fi
           ;;
      NQS) MPI_CMD="mpirun"
           ;;
   esac
fi

if [[ $WRF_TYPE = "wrfda_3dvar" ]] || [[ $WRF_TYPE = "wrfda_4dvar" ]];then
   # For WRFDA, only run da_wrfvar.exe
   case $PARALLEL_TYPE in
       serial) REAL_COMMAND=""
               WRF_COMMAND="./da_wrfvar.exe > wrfda.out 2>&1 "
               NUM_PROC=1
               ;;
       openmp) if [[ $WRF_TYPE = "wrfda_3dvar" ]];then
                  WRF_COMMAND="omplace ./da_wrfvar.exe > wrfda.out 2>&1 "
                  export OMP_NUM_THREADS=$NUM_PROC
               else
                  echo "$0: Error, ${PARALLEL_TYPE} not valid for ${WRF_TYPE}."
                  exit 4
               fi
               ;;
       mpi)    if $BATCH_TEST; then
                  REAL_COMMAND=""
                  WRF_COMMAND="$MPI_CMD ./da_wrfvar.exe "
               else
                   REAL_COMMAND=""
                   WRF_COMMAND="mpirun -machinefile machfile -np $NUM_PROC ./da_wrfvar.exe "
               fi
               ;;
   esac

elif [[ $WRF_TYPE = "wrfplus" ]];then
   # For WRFPLUS, only run wrf.exe
   case $PARALLEL_TYPE in
       serial) REAL_COMMAND=""
               WRF_COMMAND="./wrf.exe > wrfplus.out 2>&1 "
               NUM_PROC=1
               ;;
       mpi)    if $BATCH_TEST; then
                  REAL_COMMAND=""
                  WRF_COMMAND="$MPI_CMD ./wrf.exe "
               else
                   REAL_COMMAND=""
                   WRF_COMMAND="mpirun -machinefile machfile -np $NUM_PROC ./wrf.exe "
               fi
               ;;
       *) echo "$0: Error, unknown parallel setting ${PARALLEL_TYPE}."
          exit 3
   esac

else
   # For WRF, Get the invocation strings for running prewrf.exe and wrf.exe.
   case $PARALLEL_TYPE in
       serial) REAL_COMMAND="./prewrf.exe > prewrf.out 2>&1 "
               WRF_COMMAND="./wrf.exe > wrf.out 2>&1 "
               NUM_PROC=1
               ;;
       openmp) REAL_COMMAND="omplace ./prewrf.exe > prewrf.out 2>&1 "
               WRF_COMMAND="omplace ./wrf.exe > wrf.out 2>&1 "
               export OMP_NUM_THREADS=$NUM_PROC
               ;;
       mpi)    if $BATCH_TEST; then
                  REAL_COMMAND="$MPI_CMD ./prewrf.exe "
                  WRF_COMMAND="$MPI_CMD ./wrf.exe "
               else
                   REAL_COMMAND="mpirun -machinefile machfile -np $NUM_PROC ./prewrf.exe "
                   WRF_COMMAND="mpirun -machinefile machfile -np $NUM_PROC ./wrf.exe "
               fi
               ;;
   esac
fi



##
##  If test directory already exists, rename it so it has the current process ID appended to it.
##

CREATE_DIR=true
if [ -d $testDir ]; then
    if [ ! -f ${testDir}/test.sh ]; then
       # If the directory exists but does not contain test.sh, the whole testing workflow will fail
       # Need to re-create the directory for this case (can happen for re-running compile fails)
       echo "Test file 'test.sh' does not exist for existing test directory"
       echo $testDir
       echo "Re-creating the test directory"
       \rm -rf $testDir
    elif $CLOBBER; then
       newDir=${testDir}.$$
       echo "Moving existing directory '$testDir' to '$newDir'."
       mv $testDir $newDir
    else
       CREATE_DIR=false
       # If there are no failures reported from last run, skip test. 
       # Also, re-route error message about no files to /dev/null.
       fails=`ls $testDir/FAIL*.tst 2> /dev/null`
       if [ -z "$fails" -a -f $testDir/SUCCESS_FCST.tst ]; then
          echo TESTS SUCCESSFUL for $testDir... exiting early.  
          exit 0
       fi
    fi
fi



##
## Build and populate test directory; report any errors.
##

if $CREATE_DIR; then
    mkdir -p $testDir
    if [[ $? -ne 0 ]]; then
       echo "Unable to create test directory '${testDir}'; exiting test." 
       exit 2
    fi
    
    for f in $REGDATA_FILES; do
       fullpath=`makeFullPath $f $CURRENT_DIR`
       ln -sf $fullpath $testDir
       if [[ $? -ne 0 ]]; then
          echo "Unable to link regression data file $fullpath into '${testDir}'; exiting test." 
          exit 2
       fi
    done
    
    NAMELIST_PATH=`makeFullPath $NAMELIST_PATH $CURRENT_DIR`
    # Don't link namelist file, so user can experiment with settings in the working directory.
    #ln -sf $NAMELIST_PATH $testDir/namelist.input
    cp $NAMELIST_PATH $testDir/namelist.input
    if [[ $? -ne 0 ]]; then
       echo "Unable to copy namelist.input file into '${testDir}'; exiting test." 
       exit 2
    fi

    # Assume data tables exist in $WRF_ROOT_DIR/run for now; link them into the test directory.
    TBL_FILES=$(getTableNames WRF_TYPE)
    for f in $TBL_FILES; do
       fullPath=${WRF_ROOT_DIR}/run/$f 
       if [ ! -f $fullPath ]; then
          echo File does not exist; verify WRF top-level directory: $fullPath
          exit 2
       fi
       ln -sf $fullPath $testDir
    done

    # For tests requiring double-precision data tables, delete the single-precision table and link it to the double-precision one
    if [[ $WRF_TYPE = "wrfda_3dvar" || $WRF_TYPE = "wrfda_4dvar" || $WRF_TYPE = "wrfplus" || $WRF_TYPE = "em_real8" ]]; then
       DBL_FILES=`ls ${testDir}/*_DBL`
       for dbl in $DBL_FILES; do
          sgl=${dbl%????} # set "sgl" as "dbl" minus last 4 characters (for example: if dbl is RRTM_DATA_DBL, sgl will be RRTM_DATA
          \rm $sgl
          echo "Linking $dbl to $sgl"
          ln -sf $dbl $sgl
       done
    fi
    

fi    


if [[ $WRF_TYPE = "wrfda_3dvar" ]] || [[ $WRF_TYPE = "wrfda_4dvar" ]];then
   # Link in the WRFDA executable if it exists.
   wrfdaFile=$WRF_ROOT_DIR/var/build/da_wrfvar.exe

   if [ -f $wrfdaFile ]; then
      ln -sf $wrfdaFile $testDir/da_wrfvar.exe
   else
      echo "WRFDA Compile failure: File does not exist: $wrfdaFile"
      touch $testDir/FAIL_COMPILE.tst
      exit 2
   fi
elif [[ $WRF_TYPE = "wrfplus" ]];then
   # Link in the WRFPLUS executable if it exists.
   wrfplusFile=$WRF_ROOT_DIR/main/wrf.exe

   if [ -f $wrfplusFile ]; then
      ln -sf $wrfplusFile $testDir/wrf.exe
   else
      echo "WRFPLUS Compile failure: File does not exist: $wrfplusFile"
      touch $testDir/FAIL_COMPILE.tst
      exit 2
   fi
else
   # Link in the preprocessor and WRF executables if they exist.
   realFile=$WRF_ROOT_DIR/main/prewrf_${WRF_TYPE}.exe
   wrfFile=$WRF_ROOT_DIR/main/wrf.exe


   if [ -f $realFile ]; then
      ln -sf $realFile $testDir/prewrf.exe
   else
      echo "Compile failure: File does not exist(real): $realFile" > $testDir/FAIL_COMPILE.tst
      exit 2
   fi


   if [ -f $wrfFile ]; then
      ln -sf $wrfFile $testDir/wrf.exe
   else
      echo "Compile failure: File does not exist: $wrfFile"
      touch $testDir/FAIL_COMPILE.tst
      exit 2
   fi
fi

if [[ $WRF_TYPE = "wrfda_3dvar" ]] || [[ $WRF_TYPE = "wrfda_4dvar" ]];then
   # WRFDA only supports netCDF I/O
   ln -sf $WRF_ROOT_DIR/external/io_netcdf/diffwrf $testDir
elif [[ $WRF_TYPE = "wrfplus" ]];then
   ln -sf $WRF_ROOT_DIR/external/io_netcdf/diffwrf $testDir
else

   # Link in the utilities for checking WRF output; depends on the output format.
   outputForm=`grep io_form_history $testDir/namelist.input | cut -d '=' -f 2 | awk '{print $1;}'`
   case $outputForm in
       1) # Binary
          ln -sf $WRF_ROOT_DIR/external/io_int/diffwrf $testDir
          ;;
       2) # NetCDF
          ln -sf $WRF_ROOT_DIR/external/io_netcdf/diffwrf $testDir
          ;;
       5) # Grib1
          ln -sf $WRF_ROOT_DIR/external/io_grib1/wgrib.exe $testDir
          ln -sf $WRF_ROOT_DIR/external/io_grib1/diffwrf $testDir
          ;;
       *) echo "$0:  unknown WRF output format: $outputForm"
          exit 2
   esac

fi

# Create a script to actually run the test.
if $CREATE_DIR; then
    if [ "$PARALLEL_TYPE" = "mpi" ]; then    
        ##  Put all batched commands related to running the test in the local file "test.sh". 
        if [[ $BATCH_QUEUE = "share" ]] then
            cat >| $testDir/test.sh << EOF
        export MPI_USE_ARRAY=false
EOF
        fi
        cat <<EOF >> $testDir/test.sh
        \rm -f rsl.out* rsl.err*
        date >| testStart.txt
        $REAL_COMMAND
        mkdir -p rsl.PREWRF
        \mv -f rsl.out* rsl.err* rsl.PREWRF
        $WRF_COMMAND
        date >| testEnd.txt
EOF
    
        ## Also add a machine file.   Do not indent the next few lines!
        HOSTNAME=`hostname`
        cat >| $testDir/machfile << EOF
$HOSTNAME
$HOSTNAME
$HOSTNAME
$HOSTNAME
EOF
    
    else
        ##  Put all non-batched commands related to running the test in the local file "test.sh".    
        ##  Do not indent the next few lines!
        cat >| $testDir/test.sh << EOF
   echo shell = $0
   date >| testStart.txt
   $REAL_COMMAND
   $WRF_COMMAND
   date >| testEnd.txt
EOF
    fi
fi  # if $CREATE_DIR


# To allow many tests to be done in parallel, put all tests (even serial jobs) in a processing queue.  
if $BATCH_TEST; then
    case $BATCH_QUEUE_TYPE in 
        LSF) # Create a meaningful job string, so unfinished jobs can be identified easily. 
            jobString=`getJobString $WRF_TYPE $PARALLEL_TYPE $NAMELIST_PATH`
            # Look for time control spec at end of namelist
            runTime=`grep LSF_TIME $testDir/namelist.input | cut -d '=' -f 2`
            if [ -z "$runTime" ]; then
               runTime="0:05"
            fi
            BSUB="bsub -q $BATCH_QUEUE -P $BATCH_ACCOUNT -n $NUM_PROC -a poe -W $runTime -J $jobString -o test.out -e test.err -cwd $testDir "
            echo $BSUB > $testDir/submitCommand
            $BSUB < $testDir/test.sh
            ;;
        PBS) # Create a meaningful job string, so unfinished jobs can be identified easily. 
            origDir=`pwd`
            jobString=`getJobString $WRF_TYPE $PARALLEL_TYPE $NAMELIST_PATH`
            # Look for time control spec at end of namelist
            runTime=`grep PBS_TIME $testDir/namelist.input | cut -d '=' -f 2`
            if [ -z "$runTime" ]; then
               runTime="0:05:00"
            fi
            runMem=`grep MEMORY_REQ $testDir/namelist.input | cut -d '=' -f 2`
            case $PARALLEL_TYPE in
               serial) if [ -z "$runMem" ]; then
                          runMem=$BATCH_MEM
                       fi
                       BSUB="qsub -q $BATCH_QUEUE -A $BATCH_ACCOUNT -l select=1:ncpus=1:mem=${runMem}GB -l walltime=$runTime -N $jobString -o test.out -e test.err"
                       ;;
               openmp) if [ -z "$runMem" ]; then
                          (( totalMem = NUM_PROC * BATCH_MEM ))
                          runMem=$totalMem
                       fi
                       BSUB="qsub -q $BATCH_QUEUE -A $BATCH_ACCOUNT -l select=1:ncpus=$NUM_PROC:ompthreads=$NUM_PROC:mem=${runMem}GB -l walltime=$runTime -N $jobString -o test.out -e test.err"
                       ;;
               mpi)    if [ -z "$runMem" ]; then
                          (( totalMem = NUM_PROC * BATCH_MEM ))
                          runMem=$totalMem
                       fi
                       BSUB="qsub -q $BATCH_QUEUE -A $BATCH_ACCOUNT -l select=1:ncpus=$NUM_PROC:mpiprocs=$NUM_PROC:mem=${runMem}GB -l walltime=$runTime -N $jobString -o test.out -e test.err"
                       ;;
            esac
            cd $testDir
            echo $BSUB > submitCommand
            $BSUB test.sh
            cd $origDir
            ;;
        NQS) # Create a meaningful job string, so unfinished jobs can be identified easily. 
            jobString=`getJobString $WRF_TYPE $PARALLEL_TYPE $NAMELIST_PATH`
            # Look for time control spec at end of namelist
            runTime=`grep NQS_TIME $testDir/namelist.input | cut -d '=' -f 2`
            if [ -z "$runTime" ]; then
               runTime="0:05:00"
            fi
            BSUB="qsub -V -q janus-debug -l nodes=1:ppn=$NUM_PROC,walltime=$runTime -N $jobString -o $testDir/test.out -e $testDir/test.err -d $testDir"
            echo $BSUB > $testDir/submitCommand
            $BSUB $testDir/test.sh
            ;;
        *)  echo "Error: Unknown OS type '$OS_NAME'!"
            exit 2
    esac
else
    cd $testDir
    . $testDir/test.sh
fi


