#!/bin/csh

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
	module swap intel intel/14.0.2 
else if ( $OK_pgi   == 0 ) then
	echo Changing from pgi to intel environment
	module swap pgi intel
	module swap intel intel/14.0.2 
else if ( $OK_gnu   == 0 ) then
	echo Changing from gnu to intel environment
	module swap gnu intel
	module swap intel intel/14.0.2 
endif
echo

echo submit intel WTF
( nohup scripts/run_WRF_Tests.ksh -R regTest_intel_Yellowstone.wtf ) >&! foo_intel &
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit pgi WTF
module swap intel pgi
module swap pgi pgi/13.9
module list

( nohup scripts/run_WRF_Tests.ksh -R regTest_pgi_Yellowstone.wtf ) >&! foo_pgi &
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

echo submit gnu WTF
module swap pgi gnu
#module swap gnu gnu/4.8.2
module list

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
