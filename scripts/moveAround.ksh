#!/bin/ksh

ALL="             03 03DF 03FD 03VN 06 06BN 06VN 07 07NE 07VN 09 09QT 10 10VN            14         16 16BN 16DF 16VN 17 17AD 17VN 18 18BN 18VN    20 20NE 20VN                  31 31AD 31VN            38      38VN               42 42VN    48 48VN 49 49VN 50 50VN 51 52 52DF 52FD 52VN 56 56NE 56VN 57 57NE 58 58NE 60 60NE 62 global"
PGI="             03 03DF 03FD 03VN 06 06BN 06VN 07 07NE 07VN 09 09QT 10 10VN            14         16 16BN 16DF 16VN 17 17AD 17VN 18 18BN 18VN    20 20NE 20VN                  31 31AD 31VN            38      38VN         40    42 42VN    48 48VN 49 49VN 50 50VN 51 52 52DF 52FD 52VN 56 56NE 56VN 57 57NE 58 58NE 60 60NE 62 global"
GNU="             03 03DF 03FD 03VN 06 06BN 06VN 07 07NE 07VN 09 09QT 10 10VN            14 15 15AD 16 16BN 16DF 16VN 17 17AD 17VN 18 18BN 18VN    20 20NE 20VN               30 31 31AD 31VN            38 38AD 38VN 39 39AD 40    42 42VN    48 48VN 49 49VN 50 50VN 51 52 52DF 52FD 52VN 56 56NE 56VN 57 57NE 58 58NE 60 60NE 62 global"
Intel="01 02 02GR 03 03DF 03FD 03VN 06 06BN 06VN 07 07NE 07VN 09 09QT 10 10VN 12 12GR 13 14 15 15AD 16 16BN 16DF 16VN 17 17AD 17VN 18 18BN 18VN 19 20 20NE 20VN 25 26 29 29QT 30 31 31AD 31VN 33 36 36GR 38 38AD 38VN 39 39AD    41 42 42VN 43 48 48VN 49 49VN 50 50VN 51 52 52DF 52FD 52VN 56 56NE 56VN 57 57NE 58 58NE 60 60NE 62 global"


if [[ $# -eq 0 ]] ; then

	if [ -e PASS_SET_UP_ALL ];  then
		exit 0 
	fi

	\rm -rf PASS_* 2> /dev/null
	\rm -rf MPI/*
	\rm -rf SERIAL/*
	\rm -rf OPENMP/*

	cp namelist.input.* MPI

	for f in $ALL ; do
		cp namelist.input.$f OPENMP
	done
	mv namelist.input.* SERIAL
	touch PASS_SET_UP_ALL

elif [[ $# -eq 1 ]] ; then

	if   [[ $1 = PGI   ]] ; then
		if [ -e PASS_SET_UP_PGI ];  then
			exit 0 
		fi
		\rm -rf PASS_* 2> /dev/null
		\rm -rf MPI/*
		\rm -rf SERIAL/*
		\rm -rf OPENMP/*
		cp namelist.input.* MPI
		for f in $PGI ; do
			cp namelist.input.$f OPENMP
		done
		mv namelist.input.* SERIAL
		touch PASS_SET_UP_PGI


	elif [[ $1 = GNU   ]] ; then
		if [ -e PASS_SET_UP_GNU ];  then
			exit 0 
		fi
		\rm -rf PASS_* 2> /dev/null
		\rm -rf MPI/*
		\rm -rf SERIAL/*
		\rm -rf OPENMP/*
		cp namelist.input.* MPI
		cp namelist.input.* MPI
		for f in $GNU ; do
			cp namelist.input.$f OPENMP
		done
		mv namelist.input.* SERIAL
		touch PASS_SET_UP_GNU


	elif [[ $1 = Intel ]] ; then
		if [ -e PASS_SET_UP_Intel ];  then
			exit 0 
		fi
		\rm -rf PASS_* 2> /dev/null
		\rm -rf MPI/*
		\rm -rf SERIAL/*
		\rm -rf OPENMP/*
		cp namelist.input.* MPI
		for f in $Intel ; do
			cp namelist.input.$f OPENMP
		done
		mv namelist.input.* SERIAL
		touch PASS_SET_UP_Intel

	fi

fi

foo=0
if [[ -e PASS_SET_UP_ALL   ]] ; then
	(( foo+=1 ))
fi
if [[ -e PASS_SET_UP_PGI   ]] ; then
	(( foo+=1 ))
fi
if [[ -e PASS_SET_UP_GNU   ]] ; then
	(( foo+=1 ))
fi
if [[ -e PASS_SET_UP_Intel ]] ; then
	(( foo+=1 ))
fi

if [[ $foo > 1 ]] ; then
	echo ; echo ; echo "Seems that you have already re-arranged the namelist files"
	echo "Put them back in pristine order, remove all of the PASS\* files, and then try this again."
	echo
	exit 71
fi


