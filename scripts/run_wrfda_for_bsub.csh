#!/bin/csh

unsetenv MP_PE_AFFINITY

echo
echo
echo Script will submit Intel, PGI, and GNU WTF jobs to Yellowstone
echo

scripts/checkModules intel >&! /dev/null
set OK_intel = $status

scripts/checkModules pgi >&! /dev/null
set OK_pgi   = $status

scripts/checkModules gnu >&! /dev/null
set OK_gnu   = $status

if      ( $OK_intel == 0 ) then
	echo Already set up for intel environment
#module swap intel intel/14.0.2 # internal compiler error with module_bl_tempf.F, as of 11 Nov 2014
#module swap intel intel/15.0.0 # OK
#module swap intel intel/13.1.2 # OK
#module swap intel intel/13.0.1 # OK
	module swap intel intel/15.0.1
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to intel environment
	module swap pgi intel
	module swap intel intel/15.0.1 
else if ( $OK_gnu   == 0 ) then
	echo Changing from gnu to intel environment
	module swap gnu intel
	module swap intel intel/15.0.1 
endif
echo

echo submit intel WTF
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Yellowstone.wtf ) >&! foo_intel &
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit pgi WTF
module swap intel pgi
#module swap pgi pgi/13.3 # was OK but then a weird failure on 5 Dec 2014
#module swap pgi pgi/13.9 # was OK, but now all *.a files are somehow hosed, the *.o files seem to work, 8 Dec 2014
#module swap pgi pgi/14.7 # OK
#module swap pgi pgi/14.9 # was OK but fft and rsl failures 5-6 Dec 2014
module swap pgi pgi/15.1
module list

#( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Yellowstone.wtf ) >&! foo_pgi &
#echo Waiting 10 seconds to submit next job ...
#echo

sleep 10

echo submit gnu WTF
module swap pgi gnu
module swap gnu gnu/4.8.1   # trying this one
#module swap gnu gnu/4.8.2   # netcdf shared object 5 not found, fails in run
#module swap gnu gnu/4.8.3   # cannot open linker script file /glade/apps/opt/mpimod/1.3.0.7/gnu/4.8.3/syms.txt: No such file or directory, 4 Dec 2015 fails compile
#module swap gnu gnu/4.9.0   # /usr/bin/ld: cannot find -lnetcdf_c++, 5 Dec 2014
#module swap gnu gnu/4.9.1   # Nonexistent include directory "/glade/apps/opt/mpimod/1.3.0.7/gnu/4.9.1", 4 Dec 2015 fails compile
module swap gnu gnu/4.9.2
module list

( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Yellowstone_WRFDA.wtf ) >&! foo_gnu_WRFDA &
