#!/bin/ksh

if [ -e ALL_PASS_SET_UP ];  then
	exit 0 
fi

cp MPI/namelist.input.* .

\rm -rf MPI/*
\rm -rf SERIAL/*
\rm -rf OPENMP/*

cp namelist.input.* MPI

#cp namelist.input.* OPENMP

#	PGI and ALL
for f in            03 03DF 03FD 06 06BN 07 07NE 08 10            14         16 16BN 16DF 17 17AD    20 20NE                  31 31AD          37 38              40 41 42 global; do
	cp namelist.input.$f OPENMP
done

#	GNU
#for f in            03 03DF 03FD 06 06BN 07 07NE 08 10            14 15 15AD 16 16BN 16DF 17 17AD    20 20NE                  31 31AD    34    37 38 38AD 39 39AD 40 41 42 global; do
#	cp namelist.input.$f OPENMP
#done

#	INTEL
#for f in 01 02 02GR 03 03DF 03FD 06 06BN 07 07NE 08 10 12 12GR 13 14 15 15AD 16 16BN 16DF 17 17AD 19 20 20NE 25 26 29 29QT 30 31 31AD 33 34 35 37 38 38AD 39 39AD 40 41 42 global; do
#	cp namelist.input.$f OPENMP
#done

mv namelist.input.* SERIAL

touch ALL_PASS_SET_UP


