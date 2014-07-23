#!/bin/csh -f

#BSUB -a poe               # at NCAR
#BSUB -R "span[ptile=8]"   # tasks per node (16 default, 32 = hyperthreading)
#BSUB -n 8                 # number of total tasks
#BSUB -o reggie.out        # output filename
#BSUB -e reggie.err        # error filename
#BSUB -J WRF_WTF           # job name
#BSUB -q caldera           # queue: premium, regular, economy
#BSUB -W 6:00              # wallclock time hh:mm
#BSUB -P P64000400

unsetenv MP_PE_AFFINITY
scripts/run_all_for_bsub.csh
