#!/bin/csh

set tests = ( ideal chem em_real nmm da ) 

set ideal = ( em_b_wave em_hill2d_x em_quarter_ss )
set chem = ( em_chem em_chem_kpp )
set em_real = ( em_real )
set nmm = ( nmm_hwrf nmm_nest nmm_real )
set da = ( wrfda_3dvar wrfda_4dvar wrfplus )

foreach t ( $ideal $chem $em_real $nmm $da )
	
	if ( $t == em_real ) then
		cd ${t}/OPENMP
			echo "NL" > col01
			ls -1 namelist.input* | cut -c 16- >> col01

			echo "PBL" > col02
			grep bl_pbl_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col02

			echo "CU" > col03
			grep cu_physics namelist.input* | grep -v shcu | cut -d"=" -f2 | cut -d"," -f1 >> col03

			echo "MP" > col04
			grep mp_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col04

			echo "LW" > col05
			grep ra_lw_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col05

			echo "SW" > col06
			grep ra_sw_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col06

			echo "SFC" > col07
			grep sfclay_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col07

			echo "LAND" > col08
			grep surface_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col08

			echo "URB" > col09
			grep sf_urban_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col09

			echo "SHCU" > col10
			grep shcu_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col10

			echo "TOPO" > col11
			grep topo_shading namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col11

			paste col* > all

		cd ../..
	
	else if ( $t == em_quarter_ss ) then
		cd ${t}
			echo "NL" > col01
			ls -1 namelist.input* | cut -c 16- >> col01

			echo "PBL" > col02
			grep bl_pbl_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col02

			echo "CU" > col03
			grep cu_physics namelist.input* | grep -v shcu | cut -d"=" -f2 | cut -d"," -f1 >> col03

			echo "MP" > col04
			grep mp_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col04

			echo "LW" > col05
			grep ra_lw_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col05

			echo "SW" > col06
			grep ra_sw_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col06

			echo "SFC" > col07
			grep sfclay_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col07

			paste col* > all

		cd ..
	
	else if ( $t == em_b_wave ) then
		cd ${t}
			echo "NL" > col01
			ls -1 namelist.input* | cut -c 16- >> col01

			echo "PBL" > col02
			grep bl_pbl_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col02

			echo "CU" > col03
			grep cu_physics namelist.input* | grep -v shcu | cut -d"=" -f2 | cut -d"," -f1 >> col03

			echo "MP" > col04
			grep mp_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col04

			echo "LW" > col05
			grep ra_lw_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col05

			echo "SW" > col06
			grep ra_sw_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col06

			echo "SFC" > col07
			grep sfclay_physics namelist.input* | cut -d"=" -f2 | cut -d"," -f1 >> col07

			paste col* > all

		cd ..
	endif

end
