#!/bin/csh -f
#
# PBS batch script
#
# Job name
#PBS -N WTF_v03.09
# queue: share, regular, economy
#PBS -q share
# Combine error and output files
#PBS -j oe
# output filename
#PBS -o regtest.out
# error filename
#PBS -e regtest.out
# wallclock time hh:mm:ss
#PBS -l walltime=06:00:00
# Project charge code
#PBS -A P64000400
# Claim 12 cores for this script
#PBS -l select=1:ncpus=12
# Send email on abort or end of main job
#PBS -m ae


if ( ! -e Data  ) then
   echo "ERROR ERROR ERROR"
   echo ""
   echo "'Data' directory not found"
   echo "If on Cheyenne, link /glade/p/wrf/Data into your WTF directory"
   exit 1
endif

scripts/run_all_for_qsub.csh
