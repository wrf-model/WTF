#!/bin/csh

set RUN_DA = NO
set RUN_DA = YEPPERS

set INTELversion = 17.0.1
set PGIversion = 17.9
set GNUversion = 6.3.0

echo
echo
echo Script will submit GNU, Intel, and PGI WTF jobs to Cheyenne.
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

#( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Cheyenne.wtf ) >&! foo_gnu &
if ( $RUN_DA != NO ) then
	echo submit gnu WRFDA WTF
#	( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Cheyenne_WRFDA.wtf ) >&! foo_gnu_WRFDA &
endif
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

################### Intel
echo submit intel WTF
module swap gnu intel/${INTELversion}
module list
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Cheyenne.wtf ) >&! foo_intel &
if ( $RUN_DA != NO ) then
# WRFPLUS GIVES INTERNAL COMPILER ERROR, SKIP FOR NOW
        echo submit intel WRFDA WTF
#       ( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Cheyenne_WRFDA.wtf ) >&! foo_intel_WRFDA &
endif
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

################### PGI
echo submit PGI WTF
module swap intel pgi/${PGIversion}
module list
( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Cheyenne.wtf ) >&! foo_pgi &
if ( $RUN_DA != NO ) then
        echo submit pgi WRFDA WTF
#       ( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Cheyenne_WRFDA.wtf ) >&! foo_pgi_WRFDA &
endif

wait
