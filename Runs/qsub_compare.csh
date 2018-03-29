#!/bin/csh -f
#
#PBS -N COMPARE
#PBS -q share
#PBS -j oe
#PBS -o compare.out
#PBS -e compare.out
#PBS -l walltime=02:00:00
#PBS -A P64000400
#PBS -l select=1:ncpus=8:mem=20GB
#PBS -m ae

#	Make sure that diffwrf is available.

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
	You can manually do it in this script it you want: Runs/qsub_compare.csh
	setenv PATH dir-where-diffwrf-is-located:${PATH}
'EOF'
	Mail -s "FIX THIS: need diffwrf for WTF comparison test" ${user}@ucar.edu < mail.msg
endif

