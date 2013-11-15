#!/bin/csh

echo
echo
echo Script will submit Intel, PGI, and GNU WTF jobs to Yellowstone
echo

echo First, we are modifying the namelists so that they should all give a PASS
pushd Namelists/weekly/em_real >& /dev/null
#../../../scripts/moveAround.ksh
popd >& /dev/null
echo

scripts/checkModules intel >&! /dev/null
set OK_intel = $status

scripts/checkModules pgi >&! /dev/null
set OK_pgi   = $status

scripts/checkModules gnu >&! /dev/null
set OK_gnu   = $status

if      ( $OK_intel == 0 ) then
	echo Already set up for intel environment
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to intel environment
	module swap pgi intel >&! /dev/null
else if ( $OK_gnu   == 0 ) then
	echo Changing from gnu to intel environment
	module swap gnu intel >&! /dev/null
endif
echo

echo submit intel WTF
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Yellowstone.wtf ) >&! foo_intel &
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit pgi WTF
module swap intel pgi
module list
#module swap intel pgi >&! /dev/null

( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Yellowstone.wtf ) >&! foo_pgi &
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit gnu WTF
module swap pgi gnu
module list
#module swap pgi gnu >&! /dev/null

( nohup scripts/run_WRF_Tests.ksh -R regTest_gnu_Yellowstone.wtf ) >&! foo_gnu &

echo
echo
echo Starting script to monitor jobs
sleep 10


while ( 1 )

	echo jobs ; jobs ; echo
	echo bjobs ; bjobs ; echo
	date ; sleep 30 ; clear
	end

end
