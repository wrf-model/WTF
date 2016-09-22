#!/usr/bin/env python

import os

WRF_TEST_ROOT = os.getcwd()

scripts/run_wrf_tests.py -R regTest_gnu_Darwin.wtf >& run_wtf.log

