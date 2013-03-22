#!/bin/ksh

##
##   Create a table of physics options from the namelist.input files in the current directory. 
##
##   Files must be of the form "namelist.input.<TAG>".
##
##   Author: Brian Bonnlander
##

#set -x


## Create a list of namelist tags.  

namelists=`\ls -1 namelist.input.* | sed -e 's/namelist.input.//' | sort -g`

#  Put namelist tags in a file, one line per tag.  These will become the table row labels. 
echo NL > rows.txt
for d in $namelists; do
    echo $d >> rows.txt
done

   
varnames="mp_physics ra_lw_physics ra_sw_physics sf_sfclay_physics sf_surface_physics sf_urban_physics bl_pbl_physics cu_physics shcu_physics topo_wind"


#
#  Loop over physics options; create one file of values for each option.  
#
for var in $varnames; do
    # Set a column label for the physics option. 
    case $var in 
       mp_physics)    V=MP;;
       ra_lw_physics)   V=LW;;
       ra_sw_physics)   V=SW;;
       sf_sfclay_physics)   V=SFC;;
       sf_surface_physics)   V=LAND;;
       sf_urban_physics)   V=URB;;
       bl_pbl_physics)   V=PBL;;
       cu_physics)   V=CU;;
       shcu_physics)   V=SHCU;;
       topo_wind)   V=TOPO;;
       *)           V="???";;
    esac
       
    echo $V > ${var}.out

    # For each namelist, place the physics option's value in the same file, one value per line. 
    # If the physics option is not in the namelist, put the value "0" in the file. 
    for n in $namelists; do
        grep $var namelist.input.${n}  2>&1 > /dev/null
        if [ $? -eq 0 ]; then
           # option is present in the namelist.
           if [[ "$var" = "cu_physics" ]]; then
              grep $var namelist.input.${n} | grep -v shcu | awk '{print $3}' | cut -d ',' -f1 >> ${var}.out
           else
              grep $var namelist.input.${n} |                awk '{print $3}' | cut -d ',' -f1 >> ${var}.out
           fi
        else
           # option is not present in the namelist.
           echo "0" >> ${var}.out
        fi
    done
done

#  Concatenate files (one file per table column) horizontally to create a table. 
paste rows.txt *.out  > TMP

#  Replace tabs with spaces in the table.  
#expand -t5 TMP > TABLE
expand TMP > TABLE

# Clean up.
\rm TMP *.out rows.txt

