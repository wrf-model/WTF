#!/bin/csh

unsetenv MP_PE_AFFINITY
set RUN_DA = NO
set RUN_DA = YEPPERS

set INTELversion = 16.0.2
set PGIversion = 16.1
set GNUversion = 6.1.0

set INTELversion = 15.0.1
set PGIversion = 15.1
set GNUversion = 4.9.2

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
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Yellowstone.wtf ) >&! foo_intel &
if ( $RUN_DA != NO ) then
	echo submit intel WRFDA WTF
	( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Yellowstone_WRFDA.wtf ) >&! foo_intel_WRFDA &
endif
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit pgi WTF
module swap intel pgi/${PGIversion}
module list

( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Yellowstone.wtf ) >&! foo_pgi &
if ( $RUN_DA != NO ) then
	echo submit pgi WRFDA WTF
	( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Yellowstone_WRFDA.wtf ) >&! foo_pgi_WRFDA &
endif
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit gnu WTF
module swap pgi gnu/${GNUversion}
module list

( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Yellowstone.wtf ) >&! foo_gnu &
if ( $RUN_DA != NO ) then
	echo submit gnu WRFDA WTF
	( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Yellowstone_WRFDA.wtf ) >&! foo_gnu_WRFDA &
endif
