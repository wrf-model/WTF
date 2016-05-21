#!/bin/csh -f

#BSUB -a poe               # at NCAR
#BSUB -R "span[ptile=8]"   # tasks per node (16 default, 32 = hyperthreading)
#BSUB -n 8                 # number of total tasks
#BSUB -o reggie.out        # output filename
#BSUB -e reggie.err        # error filename
#BSUB -J WTF_v03.01        # job name
#BSUB -q caldera           # queue: premium, regular, economy
#BSUB -W 12:00              # wallclock time hh:mm
#BSUB -P P64000400
#BSUB -N

unsetenv MP_PE_AFFINITY
if ( ! -d /glade/scratch/${user}/TMPDIR_FOR_PGI_COMPILE ) then
	mkdir /glade/scratch/${user}/TMPDIR_FOR_PGI_COMPILE
endif
setenv TMPDIR /glade/scratch/${user}/TMPDIR_FOR_PGI_COMPILE

scripts/run_all_for_bsub.csh
