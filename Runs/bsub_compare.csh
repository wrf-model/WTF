#!/bin/csh -f

#BSUB -a poe                   # at NCAR
#BSUB -R "span[ptile=16]"      # tasks per node (16 default, 32 = hyperthreading)
#BSUB -n 1                     # number of total tasks
#BSUB -o compare.out           # output filename
#BSUB -e compare.err           # error filename
#BSUB -J COMPARE               # job name
#BSUB -q caldera               # queue: premium, regular, economy
#BSUB -W 1:00                  # wallclock time hh:mm
#BSUB -P P64000400

unsetenv MP_PE_AFFINITY

#	We need the diffwrf command to be in the path, here are a couple of ways.

#source ~/CSHRC   
#setenv PATH dir-where-diffwrf-is-located:${PATH}

#	Make sure that diffwrf is available.
#
which diffwrf >& /dev/null
set OK = $status
if ( $OK == 0 ) then
	./compare.csh
else
	if ( -e mail.msg ) then
		rm -rf mail.msg
	endif
	cat << 'EOF' > mail.msg
	WHOA THERE PARD
	You need to have diffwrf in your path
	You can manually do it in this script it you want: Runs/bsub_compare.csh
	setenv PATH dir-where-diffwrf-is-located:${PATH}
'EOF'
	Mail -s "FIX THIS: need diffwrf for WTF comparison test" ${user}@ucar.edu < mail.msg
endif
