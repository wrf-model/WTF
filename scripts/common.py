#!/usr/bin/env python

## Common.ksh
##
##  Contains python functions that are common across the scripts for building WRF, running tests,
##  and checking test results.
##
##  Author: Michael Kavulich
##  Modification history:
##          Oct 2016, Michael Kavulich, Jr.: Added new function "read_wtf" for reading test files


## Read a WTF test file (full path) and return all the necessary variables for a WTF run
def read_wtf(filename):
   print("Opening file " + filename)
   

## Read in a list of local directories and/or tar files, and prepare them to be built
def get_local_code(list_of_codes):
   print("Getting local code from " + list_of_codes)


## Read in a list of github urls and branch names, then check out and prepare that code for building
def get_github_code(list_of_urls,list_of_branches):
   print("Getting code from Github. \nURL: " + list_of_urls + "\nBranch: " + list_of_branches)


