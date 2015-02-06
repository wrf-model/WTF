#!/bin/csh

#	Compare the two Regression test results for bit-wise identical 
#	results.

#=======================================================================#
#=====     Provide the following information   =========================#
#=======================================================================#

#	Directory locations where to find the two datasets to compare.
#	The ROOT name should include no period "." and no information
#	about the compiler number afterwards.  The person who runs this
#	needs to have READ permission for both directories, but not WRITE
#	for either.  This script will output temporary files, so have WRITE
#	permission in the working directory.

set TRUTH_DIR = /glade/scratch/gill/WTF_v02.7/Runs
set TRUTH_ROOT = wrf_8029

set CHECK_DIR = /glade/scratch/weiwang/WTF_v02.7/Runs
set CHECK_ROOT = wrf2

#	How much junk do you want coming out for print info.
#		TRUE means every step gives you the thumbs up.
#		CONFIRM means that you get a positive mention for each successful comparison
#		FALSE means that you only get info on a comparison fail

set VERBOSE = FALSE
set VERBOSE = TRUE
set VERBOSE = CONFIRM

#	We will eventually need the utility "diffwrf".  So let us 
#	check for it straight away.

which diffwrf > & /dev/null
set ok = $status
if ( $ok == 0 ) then
	if ( $VERBOSE == TRUE ) echo OK, we have an availble diffwrf utility
	set DIFFWRF_LOCAL = `which diffwrf`
else
	echo TROUBLE, we need to have diffwrf in the path
	echo Dig out the copy from any built WRFV3/external/io_netcdf directory
	exit 50
	set DIFFWRF_LOCAL = /some-dir-from-you/WRFV3/external/io_netcdf/diffwrf
endif

#=======================================================================#
#=====     No changes required below     ===============================#
#=======================================================================#

#	There are a few simple Unix commands that this script assumes are
#	unfettered with user peculiarities.

unalias cd ls rm ln cp

#	Initialize counters for SAME and DIFFERENT.

set NUM_SAME = 0
set NUM_DIFF = 0

#	The failure output is sent to a file, since this takes a while to run.

if ( -e .temp_failure_file_foo ) then
	rm -rf .temp_failure_file_foo
endif
touch .temp_failure_file_foo

#	Error checking. Make sure that the listed directories do
#	indeed exist.

ls -1 ${TRUTH_DIR} | grep "${TRUTH_ROOT}\." > & /dev/null
set TRUTH_OK = $status
if ( $TRUTH_OK == 0 ) then
	if ( $VERBOSE == TRUE ) echo OK, we found the TRUTH files
else
	echo TROUBLE, we did not find the TRUTH files
	exit 100
endif

ls -1 ${CHECK_DIR} | grep "${CHECK_ROOT}\." > & /dev/null
set CHECK_OK = $status
if ( $CHECK_OK == 0 ) then
	if ( $VERBOSE == TRUE ) echo OK, we found the CHECK files
else
	echo TROUBLE, we did not find the CHECK files
	exit 200
endif

#	Are we comparing the same number of tests

set TRUTH_LIST = `ls -1 $TRUTH_DIR | grep "${TRUTH_ROOT}\."`
set CHECK_LIST = `ls -1 $CHECK_DIR | grep "${CHECK_ROOT}\."`

if ( ${#TRUTH_LIST} == ${#CHECK_LIST} ) then
	if ( $VERBOSE == TRUE ) echo OK, we are comparing the same number of tests
else
	echo TROUBLE, we are not comparing the same number of tests
	exit 300
endif

set TRUTH_COUNT = 0
set CHECK_COUNT = 0
while ( ( $TRUTH_COUNT < ${#TRUTH_LIST} ) && \
        ( $CHECK_COUNT < ${#CHECK_LIST} ) ) 
	@ TRUTH_COUNT ++
	set TRUTH_NUM = `echo $TRUTH_LIST[$TRUTH_COUNT] | cut -d"." -f2`
	@ CHECK_COUNT ++
	set CHECK_NUM = `echo $CHECK_LIST[$CHECK_COUNT] | cut -d"." -f2`

	#	Are we comparing the same test number.  This is equal to asking
 	#	if these are the same compiler settings for the regression test.

	if ( $TRUTH_NUM == $CHECK_NUM ) then
		if ( $VERBOSE == TRUE ) echo OK, we are comparing the same compiler setings
	else
		echo TROUBLE, we are not comparing the same compiler settings
		echo TRUTH: $TRUTH_NUM
		echo CHECK: $CHECK_NUM 
		exit 400
	endif

	#	Current level of directories that check out.

	set TRUTH_DIR_COMP = $TRUTH_DIR/$TRUTH_LIST[$TRUTH_COUNT]
	set CHECK_DIR_COMP = $CHECK_DIR/$CHECK_LIST[$CHECK_COUNT]

	#	Next level of directory structure down is the various 
	#	dynamical core builds (kind of).  For example, we'd expect
	#	to see em_real, nmm_nest, etc.

	set TRUTH_SUBDIR_CORES_LIST = `ls -1 $TRUTH_DIR_COMP`
	set CHECK_SUBDIR_CORES_LIST = `ls -1 $CHECK_DIR_COMP`

	#	As before, are there the same number of subdirectories
	#	in both of these

	set TRUTH_NUM = ${#TRUTH_SUBDIR_CORES_LIST}
	set CHECK_NUM = ${#CHECK_SUBDIR_CORES_LIST}

	if ( $TRUTH_NUM == $CHECK_NUM ) then
		if ( $VERBOSE == TRUE ) echo OK, same number of dynamical cores to test
	else
		echo TROUBLE, not the same number of dynamical cores
		echo TRUTH: $TRUTH_NUM $TRUTH_SUBDIR_CORES_LIST
		echo CHECK: $CHECK_NUM $CHECK_SUBDIR_CORES_LIST
		exit 500
	endif

	#	Push into the core directory structure.

	set TRUTH_CORE_COUNT = 0 
	set CHECK_CORE_COUNT = 0 

	while ( ( $TRUTH_CORE_COUNT < ${#TRUTH_SUBDIR_CORES_LIST} ) && \
		( $CHECK_CORE_COUNT < ${#CHECK_SUBDIR_CORES_LIST} ) ) 
		@ TRUTH_CORE_COUNT ++
		set TRUTH_CORE_DIR = `echo $TRUTH_SUBDIR_CORES_LIST[$TRUTH_CORE_COUNT]`
		@ CHECK_CORE_COUNT ++
		set CHECK_CORE_DIR = `echo $CHECK_SUBDIR_CORES_LIST[$CHECK_CORE_COUNT]`

		#	Verify that the core directory names are the same.

		if ( $TRUTH_CORE_DIR == $CHECK_CORE_DIR ) then
			if ( $VERBOSE == TRUE ) echo OK, the dynamical core names are the same
		else
			echo TROUBLE, the dynamical core names are not the same
			echo TRUTH: $TRUTH_CORE_DIR
			echo CHECK: $CHECK_CORE_DIR
			exit 600
		endif

		#	And now we check to see if we have the same number of namelist
		#	settings for our comparison.  This is the part of the directory
		#	that starts with "wrf_regression.namelist.input", and has 
		#	period "." delimeter, followed by a number (uually) or a
		#	character string occassionally.

		set TRUTH_SUBDIR_PHYS_LIST = `ls -1 $TRUTH_DIR_COMP/$TRUTH_CORE_DIR`
		set CHECK_SUBDIR_PHYS_LIST = `ls -1 $CHECK_DIR_COMP/$CHECK_CORE_DIR`

		set TRUTH_PHYS_NUM = ${#TRUTH_SUBDIR_PHYS_LIST}
		set CHECK_PHYS_NUM = ${#CHECK_SUBDIR_PHYS_LIST}

		#	Are we comparing the same number of physics tests.

		if ( $TRUTH_PHYS_NUM == $CHECK_PHYS_NUM ) then
			if ( $VERBOSE == TRUE ) echo OK, we are comparing the same number of physics tests
		else
			echo TROUBLE, we are not comparing the same number of physics tests
			echo TRUTH: $TRUTH_PHYS_NUM
			echo CHECK: $CHECK_PHYS_NUM
			exit 700
		endif

		#	Push into the physics test directories.

		set TRUTH_PHYS_COUNT = 0 
		set CHECK_PHYS_COUNT = 0 

		while ( ( $TRUTH_PHYS_COUNT < ${#TRUTH_SUBDIR_PHYS_LIST} ) && \
			( $CHECK_PHYS_COUNT < ${#CHECK_SUBDIR_PHYS_LIST} ) ) 
			@ TRUTH_PHYS_COUNT ++
			set TRUTH_PHYS_DIR = `echo $TRUTH_SUBDIR_PHYS_LIST[$TRUTH_PHYS_COUNT]`
			set TRUTH_PHYS_DIR = $TRUTH_PHYS_DIR:e
			@ CHECK_PHYS_COUNT ++
			set CHECK_PHYS_DIR = `echo $CHECK_SUBDIR_PHYS_LIST[$CHECK_PHYS_COUNT]`
			set CHECK_PHYS_DIR = $CHECK_PHYS_DIR:e

			if ( $TRUTH_PHYS_DIR == $CHECK_PHYS_DIR ) then
				if ( $VERBOSE == TRUE ) echo OK, we are processing the same named physics option
			else
				echo TROUBLE, we are not processing the same named phyics set
				echo TRUTH: $TRUTH_PHYS_DIR
				echo CHECK: $CHECK_PHYS_DIR
				exit 800
			endif

			#	We cannot process Binary or Grib files, so toss out this 
			#	test if either the string GR (for Grib) or BI (for binary) exists
			#	in the part of the name AFTER the period.  

			echo $TRUTH_PHYS_DIR | grep GR >& /dev/null
			set ok_GR = $status
			echo $TRUTH_PHYS_DIR | grep BI >& /dev/null
			set ok_BI = $status

			if ( ( $ok_GR != 0 ) && ( $ok_BI != 0 ) ) then
				if ( $VERBOSE == TRUE ) echo OK, this is not a Grib or Binary data set, we can use standard netcdf diffwrf
			else
				echo Cannot process this file type $TRUTH_PHYS_DIR, skipping
				goto SKIP_THIS_NON_NETCDF_PHYSICS_OPTION
			endif
			
			#	If this is a nested case, we need to compare TWO files.

			echo $TRUTH_PHYS_DIR | grep NE >& /dev/null
			set ok_NE = $status

			echo $TRUTH_PHYS_DIR | grep VN >& /dev/null
			set ok_VN = $status
		
			if ( ( $ok_NE == 0 ) || ( $ok_VN == 0 ) ) then
				set NEST = TRUE
			else
				set NEST = FALSE
			endif

			#	Now that we have tested the last part of the physics directory name, we
			#	put the whole physics directory name back together (we un-lop-off the end).

			set TRUTH_PHYS_DIR = `echo $TRUTH_SUBDIR_PHYS_LIST[$TRUTH_PHYS_COUNT]`
			set CHECK_PHYS_DIR = `echo $CHECK_SUBDIR_PHYS_LIST[$CHECK_PHYS_COUNT]`

			#	Finally, we can do a comparison.  

			set TRUTH_COMPLETE_DIR = $TRUTH_DIR/$TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR
			set CHECK_COMPLETE_DIR = $CHECK_DIR/$CHECK_LIST[$CHECK_COUNT]/$CHECK_CORE_DIR/$CHECK_PHYS_DIR

			#	First, check the namelists that made the simulation data.

			diff $TRUTH_COMPLETE_DIR/namelist.input $CHECK_COMPLETE_DIR/namelist.input >& /dev/null
			set ok = $status
			if ( $ok == 0 ) then
				if ( $VERBOSE == TRUE ) echo OK, the namelists are identical
			else
				echo TROUBLE, the namelists are not identical
				echo "TRUTH: <<<"
				echo "CHECK: >>>"
				diff $TRUTH_COMPLETE_DIR/namelist.input $CHECK_COMPLETE_DIR/namelist.input
				exit 900
			endif

			#	Now we can compare the netcdf results themselves.

			if ( -e fort.88 ) then
				rm -rf fort.88
			endif

			if ( -e fort.98 ) then
				rm -rf fort.98
			endif

			#	Do we have both of these wrfout_d01 files laying around to compare
	
			ls -1 $TRUTH_DIR/$TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR | grep wrfout_d01 >& /dev/null
			set ok_TRUTH_d01_exist = $status
	
			ls -1 $CHECK_DIR/$CHECK_LIST[$CHECK_COUNT]/$CHECK_CORE_DIR/$CHECK_PHYS_DIR | grep wrfout_d01 >& /dev/null
			set ok_CHECK_d01_exist = $status
	
			if ( ( $ok_TRUTH_d01_exist == 0 ) && ( $ok_CHECK_d01_exist == 0 ) ) then
				if ( $VERBOSE == TRUE ) echo OK, TRUTH and CHECK d01 files exist
			else
				echo "TROUBLE, skipping comparison, as one of both files do not exist"
				echo "TROUBLE, skipping comparison, as one of both files do not exist" >> .temp_failure_file_foo
				goto TURNS_OUT_WE_HAVE_NO_D01
			endif

			set TRUTH_FILE = $TRUTH_DIR/$TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR/wrfout_d01*
			set CHECK_FILE = $CHECK_DIR/$CHECK_LIST[$CHECK_COUNT]/$CHECK_CORE_DIR/$CHECK_PHYS_DIR/wrfout_d01*
			$DIFFWRF_LOCAL $TRUTH_FILE $CHECK_FILE >& /dev/null
			if ( ( ! -e fort.88 ) && ( ! -e fort.98 ) ) then
				if ( ( $VERBOSE == TRUE ) || ( $VERBOSE == CONFIRM ) ) echo $TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR wrfout_d01 files SAME
				@ NUM_SAME ++
			else
				echo "TROUBLE, --->  the two $TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR wrfout_d01 files are different"
				echo "TROUBLE, --->  the two $TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR wrfout_d01 files are different" >> .temp_failure_file_foo
				@ NUM_DIFF ++
#				exit 1000
			endif

			if ( -e fort.88 ) then
				rm -rf fort.88
			endif

			if ( -e fort.98 ) then
				rm -rf fort.98
			endif

			if ( $NEST == TRUE ) then

				#	There were some missing files in older nml files (max_dom=1 for NE cases).  Oops.
				#	Test for existence.
	
				ls -1 $TRUTH_DIR/$TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR | grep wrfout_d02 >& /dev/null
				set ok_TRUTH_nest_exist = $status
	
				ls -1 $CHECK_DIR/$CHECK_LIST[$CHECK_COUNT]/$CHECK_CORE_DIR/$CHECK_PHYS_DIR | grep wrfout_d02 >& /dev/null
				set ok_CHECK_nest_exist = $status
	
				if ( ( $ok_TRUTH_nest_exist == 0 ) && ( $ok_CHECK_nest_exist == 0 ) ) then
					if ( $VERBOSE == TRUE ) echo OK, TRUTH and CHECK nest files exist
				else
					echo "TROUBLE, you have an NE named file that has no nest FIX THIS"
					echo "TROUBLE, you have an NE named file that has no nest FIX THIS" >> .temp_failure_file_foo
					goto TURNS_OUT_WE_HAVE_NO_NEST
				endif

				set TRUTH_FILE = $TRUTH_DIR/$TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR/wrfout_d02*
				set CHECK_FILE = $CHECK_DIR/$CHECK_LIST[$CHECK_COUNT]/$CHECK_CORE_DIR/$CHECK_PHYS_DIR/wrfout_d02*
				$DIFFWRF_LOCAL $TRUTH_FILE $CHECK_FILE >& /dev/null
				if ( ( ! -e fort.88 ) && ( ! -e fort.98 ) ) then
					if ( ( $VERBOSE == TRUE ) || ( $VERBOSE == CONFIRM ) ) echo $TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR wrfout_d02 files SAME
					@ NUM_SAME ++
				else
					echo "TROUBLE, --->  the two $TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR wrfout_d02 files are different"
					echo "TROUBLE, --->  the two $TRUTH_LIST[$TRUTH_COUNT]/$TRUTH_CORE_DIR/$TRUTH_PHYS_DIR wrfout_d02 files are different" >> .temp_failure_file_foo
					@ NUM_DIFF ++
#					exit 1100
				endif
			endif

TURNS_OUT_WE_HAVE_NO_D01:

TURNS_OUT_WE_HAVE_NO_NEST:
	
SKIP_THIS_NON_NETCDF_PHYSICS_OPTION: 

		end	#	Loop over the physics options: 01NE, global
		
	end 		#	Loop over the core directories: em_real, nmm_nest

end			#	Loop over compiler numbers: 13, 14, 15 for Intel

echo
echo Total number of identical file tests: $NUM_SAME
echo Total number of different file tests: $NUM_DIFF
echo
echo List of failures
cat .temp_failure_file_foo
echo

