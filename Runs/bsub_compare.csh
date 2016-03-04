#!/bin/csh -f

#BSUB -a poe                   # at NCAR
#BSUB -R "span[ptile=16]"      # tasks per node (16 default, 32 = hyperthreading)
#BSUB -n 1                     # number of total tasks
#BSUB -o compare.out              # output filename
#BSUB -e compare.err              # error filename
#BSUB -J COMPARE_diff          # job name
#BSUB -q caldera               # queue: premium, regular, economy
#BSUB -W 1:00                  # wallclock time hh:mm
#BSUB -P P64000400

unsetenv MP_PE_AFFINITY
source ~/CSHRC   # we need the diffwrf command to be in the path
./compare.csh
