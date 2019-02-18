#!/bin/csh

set RUN_DA = NO
#set RUN_DA = YEPPERS

set PGIversion = 16.5

echo
echo
echo Script will submit PGI WTF jobs to Cheyenne.
echo

scripts/checkModules intel >&! /dev/null
set OK_intel = $status

scripts/checkModules pgi >&! /dev/null
set OK_pgi   = $status

scripts/checkModules gnu >&! /dev/null
set OK_gnu   = $status

if      ( $OK_gnu == 0 ) then
	echo Already set up for pgi environment
	module swap gnu pgi/${PGIversion}
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to pgi environment
	module swap pgi pgi/${PGIversion}
else if ( $OK_intel == 0 ) then
	echo Changing from intel to pgi environment
	module swap intel pgi/${PGIversion}
endif
module list
echo

################### PGI
echo submit PGI WTF
module swap intel pgi/${PGIversion}
module load netcdf
module list
( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Cheyenne.wtf ) >&! foo_pgi &
if ( $RUN_DA != NO ) then
        echo submit pgi WRFDA WTF
        ( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Cheyenne_WRFDA.wtf ) >&! foo_pgi_WRFDA &
endif

wait
