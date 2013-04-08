#!/bin/ksh

if [ -e ALL_PASS_SET_UP ];  then
	exit 0 
fi

cp MPI/namelist.input.* .

\rm -rf MPI/*
\rm -rf SERIAL/*
\rm -rf OPENMP/*

cp namelist.input.* MPI

for f in 03 03DF 03FD 06 06BN 07 07NE 08 10 14 16 16BN 16DF 17 17AD 20 20NE 31 31AD 40 41 42 global; do
	cp namelist.input.$f OPENMP
done

mv namelist.input.* SERIAL

touch ALL_PASS_SET_UP


