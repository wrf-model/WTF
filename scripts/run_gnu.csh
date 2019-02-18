#!/bin/csh

set RUN_DA = NO
#set RUN_DA = YEPPERS

set GNUversion = 6.3.0

echo
echo
echo Script will submit GNU WTF jobs to Cheyenne.
echo

scripts/checkModules intel >&! /dev/null
set OK_intel = $status

scripts/checkModules pgi >&! /dev/null
set OK_pgi   = $status

scripts/checkModules gnu >&! /dev/null
set OK_gnu   = $status

if      ( $OK_gnu == 0 ) then
	echo Already set up for gnu environment
	module swap gnu gnu/${GNUversion}
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to gnu environment
	module swap pgi gnu/${GNUversion}
else if ( $OK_intel == 0 ) then
	echo Changing from intel to gnu environment
	module swap intel gnu/${GNUversion}
endif
module list
echo

################### GNU
echo submit gnu WTF

( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Cheyenne.wtf ) >&! foo_gnu &
if ( $RUN_DA != NO ) then
	echo submit gnu WRFDA WTF
	( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Cheyenne_WRFDA.wtf ) >&! foo_gnu_WRFDA &
endif

wait
