import fileinput
from subprocess import call
import sys
import os

script=open("postinstall_script","w")
postinstall=False
shell=None
for line in sys.stdin:
    if "postinstall scriptlet" in line:
        shell=line.split()[3][:-2]
        script.write("#!"+shell)
        if not shell:
             print("ERROR: shell not detected from rpm -q --scripts")
             sys.exit(1)
        print("postinstall script using "+shell+" detected")
        print("================================================")
        postinstall=True
        continue
    elif "scriptlet" in line:
        postinstall=False
        continue
    if postinstall:
        script.write(line)
        print(line[:-1]) # remove "\n"

#script.write("[ 1 = 0 ]") # just for testing scriptlet failure :)
script.close()
print("================================================\n")

# execute postinstall script
if shell is None:
    print("no postinstall scripts found...")
    retval = 0
else:
    print("executing postinstall script...")
    retval=call([shell,"postinstall_script"])
if retval != 0:
    print("ERROR: scriptlet failure")
sys.exit(retval)
