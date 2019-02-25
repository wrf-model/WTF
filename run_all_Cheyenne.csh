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
screen -d -m -S pgi_WTF_v04.08 bash -c 'scripts/run_pgi.csh >& regtest_pgi.out'
screen -list
echo

wait
