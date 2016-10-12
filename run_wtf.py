#!/usr/bin/env python

import os
import time

import run_wrf_tests

starttime = time.asctime( time.localtime(time.time()) )
print "Starting WTF :", starttime

wrf_test_root = os.getcwd()

run_test("regTest_gnu_Darwin.wtf")

endtime = time.asctime( time.localtime(time.time()) )
print "Starting WTF :", endtime


