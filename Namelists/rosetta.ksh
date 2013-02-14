#!/bin/ksh

#namelists=`seq 1 17`
#namelists="1 3 5 7 8 10 12 13 14 15 16 17 18"

set -x

namelists=`\ls namelist.input.*`
nl=""

for n in $namelists; do
   nl="$nl `echo $n | cut -d'.' -f3`"
done

echo $nl
namelists=$nl

#namelists="27 28 29 30"

echo NL > rows.txt
for d in $namelists; do
    echo $d >> rows.txt
done

   
varnames="mp_physics ra_lw_physics ra_sw_physics sf_sfclay_physics sf_surface_physics bl_pbl_physics cu_physics shcu_physics topo_wind"



for var in $varnames; do
    \rm ${var}.out
    case $var in 
       mp_physics)    V=MP;;
       ra_lw_physics)   V=LW;;
       ra_sw_physics)   V=SW;;
       sf_sfclay_physics)   V=SFC;;
       sf_surface_physics)   V=LAND;;
       bl_pbl_physics)   V=PBL;;
       cu_physics)   V=CU;;
       shcu_physics)   V=SHCU;;
       topo_wind)   V=TOPO;;
    esac
       
    echo $V > ${var}.out

    for n in $namelists; do
        if [[ "$var" = "cu_physics" ]]; then
           echo Matched cu_physics
           grep $var namelist.input.${n} | grep -v shcu | awk '{print $3}' | cut -d ',' -f1 >> ${var}.out
        else
           grep $var namelist.input.${n} |                awk '{print $3}' | cut -d ',' -f1 >> ${var}.out
        fi
    done
done


paste rows.txt *.out  > TMP

expand -t5 TMP > TABLE
\rm TMP *.out 

