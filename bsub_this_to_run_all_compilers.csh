#!/bin/csh -f

#BSUB -a poe               # at NCAR
#BSUB -R "span[ptile=16]"  # tasks per node (16 default, 32 = hyperthreading)
#BSUB -n 16                # number of total tasks
#BSUB -o reggie.out        # output filename
#BSUB -e reggie.err        # error filename
#BSUB -J WTF_v03.06        # job name
#BSUB -q caldera           # queue: premium, regular, economy
#BSUB -W 6:00              # wallclock time hh:mm
#BSUB -P P64000400
#BSUB -N

unsetenv MP_PE_AFFINITY

if ( ! -e Data  ) then
   echo "ERROR ERROR ERROR"
   echo ""
   echo "'Data' directory not found"
   echo "If on Yellowstone, link /glade/p/wrf/Data into your WTF directory"
   exit 1
endif

if ( ! -d /glade/scratch/${user}/TMPDIR_FOR_PGI_COMPILE ) then
	mkdir /glade/scratch/${user}/TMPDIR_FOR_PGI_COMPILE
endif
setenv TMPDIR /glade/scratch/${user}/TMPDIR_FOR_PGI_COMPILE

scripts/run_all_for_bsub.csh
