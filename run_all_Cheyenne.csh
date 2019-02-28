#!/bin/csh


################### GNU
echo submit gnu WTF
qsub qsub_gnu.pbs
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

################### Intel
echo submit intel WTF
qsub qsub_intel.pbs
echo Waiting 10 seconds to submit next job ...
echo

sleep 10

################### PGI
echo submit PGI WTF
qsub qsub_pgi.pbs
echo Waiting all the jobs ...
echo 

wait
