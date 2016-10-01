#!/usr/bin/env python

import os
import time;

starttime = time.asctime( time.localtime(time.time()) )
print "Starting WTF :", starttime

WRF_TEST_ROOT = os.getcwd()

scripts/run_wrf_tests.py -R regTest_gnu_Darwin.wtf >& run_wtf.log

endtime = time.asctime( time.localtime(time.time()) )
print "Starting WTF :", endtime


