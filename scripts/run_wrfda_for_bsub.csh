#!/bin/csh

unsetenv MP_PE_AFFINITY

set INTELversion = 15.0.1
set PGIversion = 15.1
set GNUversion = 4.9.2

set INTELversion = 16.0.2
set PGIversion = 15.10
set GNUversion = 5.3.0

echo
echo
echo Script will submit Intel and GNU WTF jobs to Yellowstone
echo

scripts/checkModules intel >&! /dev/null
set OK_intel = $status

scripts/checkModules pgi >&! /dev/null
set OK_pgi   = $status

scripts/checkModules gnu >&! /dev/null
set OK_gnu   = $status

if      ( $OK_intel == 0 ) then
	echo Already set up for intel environment
	module swap intel intel/${INTELversion}
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to intel environment
	module swap pgi intel/${INTELversion}
else if ( $OK_gnu   == 0 ) then
	echo Changing from gnu to intel environment
	module swap gnu intel/${INTELversion}
endif
module list
echo

echo submit intel WTF
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Yellowstone_WRFDA.wtf ) >&! foo_intel_WRFDA &

echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit gnu WTF
module swap pgi gnu/${GNUversion}
module list

( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Yellowstone_WRFDA.wtf ) >&! foo_gnu_WRFDA &
