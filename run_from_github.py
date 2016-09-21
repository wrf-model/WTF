#!/usr/bin/python
import os
import shutil
import tarfile

url = raw_input('Enter github URL (leave blank for https://github.com/wrf-model/WRF): ')
branch = raw_input('Enter branch name (leave blank for master): ')

if not url:
   url = "https://github.com/wrf-model/WRF"

if not branch:
   branch = "master"

print "Repository URL is %s." % url
print "Branch name is %s." % branch

os.chdir("tarballs")

if os.path.isdir("WRFV3"):
   shutil.rmtree("WRFV3")

os.system("git clone " + url + " WRFV3")
os.chdir("WRFV3")
os.system("git checkout " + branch)
os.chdir("../")

out = tarfile.open("github_" + branch + ".tar", mode='w')
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

