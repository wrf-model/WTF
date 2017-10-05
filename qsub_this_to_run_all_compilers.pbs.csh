#!/bin/csh -f
#
# PBS batch script
#
# Job name
#PBS -N WTF_v04.01
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
# Claim 18 cores for this script (individual jobs created by this script can use way more)
#PBS -l select=1:ncpus=8:mem=40GB
# Send email on abort or end of main job
#PBS -m ae


if ( ! -e Data  ) then
   echo "ERROR ERROR ERROR"
   echo ""
   echo "'Data' directory not found"
   echo "If on Cheyenne, link /glade/p/wrf/Data into your WTF directory"
   echo ""
   echo "Otherwise, it can be downloaded from http://www2.mmm.ucar.edu/wrf/tmp/"
   exit 1
endif

if ( ! -e Data/v04.01  ) then
   echo "ERROR ERROR ERROR"
   echo ""
   echo "'Data' directory is not the correct version (v04.01)"
   echo "If on Cheyenne, link /glade/p/wrf/Data into your WTF directory"
   echo ""
   echo "Otherwise, it can be downloaded from http://www2.mmm.ucar.edu/wrf/tmp/data_v04.01.tar"
   exit 2
endif

setenv TMPDIR /glade/scratch/$USER/tmp # CISL-recommended hack for Cheyenne builds

scripts/run_all_for_qsub.csh
