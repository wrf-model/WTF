#!/usr/bin/python
#
# A python script for running a WTF straight from Github, just specifying a URL and branch name.
# For now, this only works on batch machines (Yellowstone and Cheyenne). 
# Future modifications will be needed to allow for use on local machines.
#
# Usage: ./run_from_github.py
#        When prompted, enter a repository URL.
#        When prompted, enter a branch name.
#        Alternatively, you can also enter the "--url" and/or "--branch" options via command line arguments
# 
# Author: Michael Kavulich, Jr. (September 2016)
#         Update history:
#         November 2016: Added command-line arguments for url and branch
#


import os
import re
import sys
import shutil
import tarfile
import subprocess


def usage(exit_code=0): #If no exit code is specified, this indicates successful execution, so return exit code "0" per convention

   print("usage: " + __file__ + " --url=https://github.com/wrf-model/WRF --branch=branch_name")
   print("")
   print("       " + __file__ + " url   : The main URL of the Github repository you wish to test (e.g. https://github.com/username/WRF for your fork)")
   print("       " + __file__ + " branch : The name of the branch you wish to test")
   sys.exit(exit_code)


def main():

 # Define these as "None" for future checks
 url=None
 branch=None

 # Keep track of version number for Data directory
 version="v04.08"

 # First things first: check if user has a "Data" directory, quit with helpful message if they don't
 if not os.path.isdir("Data"):
    print("\nERROR ERROR ERROR\n")
    print("'Data' directory not found")
    print("If on Yellowstone or Cheyenne, link /glade/p/wrf/Data into your WTF directory")
    print("If you do not have access to Yellowstone or Cheyenne, you can download the data from http://www2.mmm.ucar.edu/wrf/tmp/data_"+version+".tar")
    sys.exit("\nExiting script")
 elif not os.path.isfile("Data/" + version):
    print("\nERROR ERROR ERROR\n")
    print("Your 'Data' directory is too old to work with this version of the WTF. You need version " + version)
    print("If on Yellowstone or Cheyenne, link /glade/p/wrf/Data into your WTF directory")
    print("If you do not have access to Yellowstone or Cheyenne, you can download the data from http://www2.mmm.ucar.edu/wrf/tmp/data_"+version+".tar")
    sys.exit("\nExiting script")

 tardir = "tarballs"
 builddir = "Builds"
 rundir = "Runs"

 if len(sys.argv) > 1:
    for arg in sys.argv[1:]:
       if "--url=" in arg:
          url=arg.split("=",1)[1]
       elif "--branch=" in arg:
          branch=arg.split("=",1)[1]
       elif ("--help" in arg) or ("-h" in arg):
          usage()
       else:
          print("Unrecognized option: " + arg)
          usage(1)

 ls_proc = subprocess.Popen(["ls", "-l", tardir], stdout=subprocess.PIPE)
 (out, err) = ls_proc.communicate()
 if err:
    sys.exit("`ls -l` returned an error, this shouldn't happen!")

 tardirfiles = out.splitlines()

 i = 0
 for tardirfile in tardirfiles:
    maybetarfile = tardirfile.split(" ")
    maybetarfile = maybetarfile[-1]            # need to extract "testname", which is in the last column of the "ls" output
    regexp = re.compile(r'tar$')
    if regexp.search(maybetarfile) is not None:
       if i == 0:
          print("\nWARNING:\nFound existing tar file(s):")
       print(maybetarfile)
       i =+ 1
       continue

 if i > 0:
    cont = ''
    print("\nIf you choose to continue, tests will be run using these existing files AS WELL AS your github-specified test\n")
    while not cont:
       cont = raw_input("Do you wish to continue? (y/n) ")
       if re.match('y', cont, re.IGNORECASE) is not None:
          break
       elif re.match('n', cont, re.IGNORECASE) is not None:
          print("User specified exit.\nRemove tar files in the '" + tardir + "' directory if you do not wish to run tests using those tar files.")
          sys.exit(0)
       else:
          print("Unrecognized input: " + cont)
          cont=''


 if url is None:
    url = raw_input('\nEnter github URL (leave blank for https://github.com/wrf-model/WRF): ')
    url = url.strip()

 if branch is None:
    branch = raw_input('Enter branch name (leave blank for master): ')
    branch = branch.strip()

 spaces = re.compile(r'\s')
 if (re.search(spaces, url) is not None):
    print("FATAL:\nInvalid URL: contains whitespace character(s)")
    sys.exit(2)
 elif (re.search(spaces, branch) is not None):
    print("FATAL:\nInvalid branch name: contains whitespace character(s)")
    sys.exit(3)

 if "/tree/" in url:
    print("The URL you typed appears to be a direct link to a branch rather than the top-level URL of a repository. \nYour URL should probably be in the format 'https://github.com/username/WRF/'.")
    sys.exit(4)
 if not url:
    url = "https://github.com/wrf-model/WRF"

 #In the future we hope to run tests from multiple forks, so we should disambiguate the tar files by adding the fork name
 urlsplit = url.split("/")
 if "http" in urlsplit[0]:
    fork = urlsplit[3]
 else: # Assume if it is not http then user is using ssh
    urlsplitagain = urlsplit[0].split(":")
    fork = urlsplitagain[1]

 if not branch:
    branch = "master"

 print "Repository URL is %s." % url
 if "wrf-model" not in fork:
    print "Fork is %s." % fork
 print "Branch name is %s." % branch
 
 os.chdir(tardir)

 if os.path.isdir("WRF"):
    cont = ''
    print("\nWARNING: \n" + tardir + "/WRF already exists.\nIf you continue, this directory will be deleted and overwritten.\n")
    while not cont:
       cont = raw_input("Do you wish to continue? (y/n) ")
       if re.match('y', cont, re.IGNORECASE) is not None:
          break
       elif re.match('n', cont, re.IGNORECASE) is not None:
          print("User specified exit.")
          sys.exit(0)
       else:
          print("Unrecognized input: " + cont)
          cont=''
    shutil.rmtree("WRF")

 os.system("git clone " + url + " WRF")
 os.chdir("WRF")

 # We have to check the exit status of git checkout, otherwise we may not get the right code!
 err = subprocess.call(["git", "checkout", branch])
# (out, err) = checkout_proc.communicate()
 if err:
    sys.exit("There was an error checking out " + branch + ", see above for details")

 os.chdir("../")


 testname = "github_" + fork + "_" + branch
 tarname = testname + ".tar"
 if os.path.isfile(tarname):
    cont = ''
    print("\nWARNING: \n" + tardir + "/" + tarname + " already exists, so you have probably already run this test.\nIf you continue, this file will be overwritten, and all old test directories deleted.\n")
    while not cont:
       cont = raw_input("Do you wish to continue? (y/n) ")
       if re.match('y', cont, re.IGNORECASE) is not None:
          break
       elif re.match('n', cont, re.IGNORECASE) is not None:
          print("User specified exit.")
          sys.exit(0)
       else:
          print("Unrecognized input: " + cont)
          cont=''
 os.chdir("../")
 del_dirs = None
 del_dirs = [dir for dir in os.listdir(builddir) if re.search(r'^'+testname+'\.\d+$', dir)]
 if del_dirs is None:
    del_dirs = [dir for dir in os.listdir(rundir) if re.search(r'^'+testname+'\.\d+$', dir)]
 os.chdir(tardir)
 if del_dirs:
    cont = ''
    print("\nWARNING WARNING WARNING: \nYou have existing builds/runs for a test named " + testname + ": If you continue, these old test directories deleted!\n")
    while not cont:
       cont = raw_input("Do you wish to continue? (y/n) ")
       if re.match('y', cont, re.IGNORECASE) is not None:
          break
       elif re.match('n', cont, re.IGNORECASE) is not None:
          print("User specified exit.")
          sys.exit(0)
       else:
          print("Unrecognized input: " + cont)
          cont=''
    os.chdir("../")
    os.system('./clean --name=' + testname)
    os.chdir(tardir)

 out = tarfile.open(tarname, mode='w')
 try:
    out.add('WRF') # Adding "WRF" directory to tar file
 finally:
    out.close() # Close tar file

 os.chdir("../")
 
 cont=''
 while not cont:
 	cont = raw_input("Are you using Cheyenne? (y/n) ")
 	if re.match('y', cont, re.IGNORECASE) is not None:
 		os.system('./run_all_Cheyenne.csh >& cheyenne.log &')
 	elif re.match('n', cont, re.IGNORECASE) is not None:
 		os.system('qsub < qsub_this_to_run_all_compilers.pbs.csh')
 	else:
 		print("Unrecognized input: " + cont)
        	cont=''

if __name__ == "__main__":
    main()


