#!/usr/bin/python
#
# A python script for running a WTF straight from Github, just specifying a URL and branch name.
# For now, this only works on Yellowstone. Future modifications will allow for use on local machines.
#
# Usage: ./run_from_github.py
#        When prompted, enter a repository URL.
#        When prompted, enter a branch name.
# 
# Author: Michael Kavulich, Jr. (September 2016)
#


import os
import shutil
import tarfile

url = raw_input('Enter github URL (leave blank for https://github.com/wrf-model/WRF): ')
branch = raw_input('Enter branch name (leave blank for master): ')

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

os.chdir("tarballs")

if os.path.isdir("WRFV3"):
   shutil.rmtree("WRFV3")

os.system("git clone " + url + " WRFV3")
os.chdir("WRFV3")
os.system("git checkout " + branch)
os.chdir("../")



out = tarfile.open("github_" + fork + "_" + branch + ".tar", mode='w')
try:
    out.add('WRFV3') # Adding "WRFV3" directory to tar file
finally:
    out.close() # Close tar file

os.chdir("../")

user = os.environ.get("USER")

del(os.environ["MP_PE_AFFINITY"])
if not os.path.isdir("/glade/scratch/" + user + "/TMPDIR_FOR_PGI_COMPILE"):
   os.makedirs("/glade/scratch/" + user + "/TMPDIR_FOR_PGI_COMPILE")
os.environ["TMPDIR"] = "/glade/scratch/" + user + "/TMPDIR_FOR_PGI_COMPILE"


os.system('bsub < bsub_this_to_run_all_compilers.csh')

