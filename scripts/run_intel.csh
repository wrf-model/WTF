#!/bin/csh

set RUN_DA = NO
#set RUN_DA = YEPPERS

set INTELversion = 17.0.1

echo
echo
echo Script will submit Intel WTF jobs to Cheyenne.
echo

scripts/checkModules intel >&! /dev/null
set OK_intel = $status

scripts/checkModules pgi >&! /dev/null
set OK_pgi   = $status

scripts/checkModules gnu >&! /dev/null
set OK_gnu   = $status

if      ( $OK_gnu == 0 ) then
	echo Already set up for intel environment
	module swap gnu intel/${INTELversion}
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to intel environment
	module swap pgi intel/${INTELversion}
else if ( $OK_intel == 0 ) then
	echo Changing from intel to intel environment
	module swap intel intel/${INTELversion}
endif
module list
echo

################### Intel
echo submit intel WTF
module swap gnu intel/${INTELversion}
module list
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Cheyenne.wtf ) >&! foo_intel &
if ( $RUN_DA != NO ) then
# WRFPLUS GIVES INTERNAL COMPILER ERROR, SKIP FOR NOW
        echo submit intel WRFDA WTF
        ( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Cheyenne_WRFDA.wtf ) >&! foo_intel_WRFDA &
endif
echo

wait
