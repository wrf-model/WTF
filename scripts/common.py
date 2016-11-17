#!/usr/bin/env python

## common.py
##
##  Contains python classes and functions that are common across the scripts for building WRF, running tests,
##  and checking test results.
##
##  Author: Michael Kavulich
##  Modification history:
##          Oct 2016, Michael Kavulich, Jr.: Adding classes for "code_to_test" and "test"


##### CLASSES

class code_to_test:
   'A class for different copies of the code to test. Can be a local directory/tar file, or a github branch'
   code_count = 0
   
   def __init__(self, git, path, branch=''):
      self.git = git           # True if a git repository, False if tarball or directory
      self.path = path         # local path or remote url
      self.branch = branch     # branch (only valid if git repository)
      if (branch is ''):
         if git:
            branch = 'master'
         else:
            print("Error: can not specify 'branch' if 'git' is False")
            sys.exit(1)

      code_to_test.code_count += 1

class test:
   'A class for different tests to run'
   test_count = 0

   def __init__(self, compiler='', build_types=[], batch=False, configure_opts=[], other_params=[]):
      self.compiler = compiler              # Compiler name
      self.build_types = build_types        # list of build type objects
      self.batch = batch                    # Specify batch compile (for Yellowstone, e.g.)
      self.other_params = other_params      # list of other parameters from wtf file

      test.test_count += 1


class build_type:
   'A class for build types (em_real, em_chem, wrfda_3dvar, etc)'

   def __init__(self, name, status):
      self.name = name                       # Test name (em_real, em_chem, wrfda_3dvar, etc)
      self.config_opts = []                  # List of integers which define configure types (as set in WRF configure script)
      self.depend = build_depend(self.name)  # List of dependencies for this test
      self.status = 'pending'                # State of build
                                             #    pending:  Ready to build
                                             #    waiting:  Waiting until prerequisites (listed in self.depend) are built
                                             #    building: Build in progress
                                             #    done:     Done building!
                                             #    error:    Error in build.

# Need new type: config_type for holding "status" of each build

##### FUNCTIONS

## The funciton build_depend is fed a build string and returns an empty if that build can be built right away, or else it returns the corresponding build string that this build must wait for
def build_depend(bs):
 if ("em_b_wave" in bs ) or ("em_quarter_ss" in bs):
    return "em_real"
 elif "em_quarter_ss8" in bs:
    return "em_real8"
 elif "wrfda_4dvar" in bs:
    return "wrfplus"
 else:
    return ''


## Read a WTF test file (full path) and return all the necessary variables for a WTF run
#def read_wtf(filename):
#   print("Opening file " + filename)
   

## Read in a list of local directories and/or tar files, and prepare them to be built
def get_local_code(list_of_codes):
   print("Getting local code from " + list_of_codes)


## Read in a list of github urls and branch names, then check out and prepare that code for building
def get_github_code(list_of_urls,list_of_branches):
   print("Getting code from Github. \nURL: " + list_of_urls + "\nBranch: " + list_of_branches)


