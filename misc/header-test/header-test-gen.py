"""
header-test-gen - generates kernel-headers test

This test will try to compile each exported kernel header file separately.
Most of the headers can be compiled without any explicit dependencies,
others need extra care:
1. they need to include some kernel header(s)
2. they need to include libc header(s)
3. they need type/struct, which isn't in kernel headers nor libc headers
4. they can't be compiled due to other errors

This test will look at current kernel version to figure out
rhel release, kernel version and arch. Then it will search for all files in:
$release/common/ and $release/$arch/, whose kernel version is less or equal
to current kernel version. These files serve as updates to get newer
kernel headers versions to compile, but without risk of affecting
older kernel versions when this test gets updated.
"""
from __future__ import print_function
__author__ = """Copyright Jan Stancek 2011"""
__maintainer__ = """Jeff Bastian 2019"""


import os
import sys
import shutil
import stat
import platform
import imp
import re
import rpm
from flags import *

exc = {}
# exc[header] = includes/extra, FLAG, comment
header_list = []
test_list = []
test_dir = '/tmp/header-test'
headers_root_dir = None
verify = bool(os.environ.get('VERIFY') == 'yes')

def getArch():
    arch = platform.machine()
    if arch == 'ppc64le':
        arch = 'ppc64'
    return arch

def getRelease():
    release_str = platform.release()
    current_release = parseRelease(release_str)
    return current_release

def getVersion():
    release_str = platform.release()
    current_version = parseVersion(release_str)
    return current_version

def parseVersion(release_str):
     m = re.search('^(\d+)\.(\d+)\.(\d+)-(\d+)\.(\d+)', release_str)
     if m:
         return int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))

     m = re.search('^(\d+)\.(\d+)\.(\d+)-(\d+)', release_str)
     if m:
         return int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))
     else:
         return (0,0,0,0)

def parseRelease(release_str):
     m = re.search('\.(((el|sa)\d)|aa7a)', release_str)
     if m:
         return m.group(1)
     else:
         return None

def isVersionLessOrEqual(version, cur_version):
    if len(version) <= len(cur_version):
        # do not inherit across major versions
        # i.e., kernel 4.y.z should not read kernel 2.y.z nor 3.y.z files
        if len(version) > 0 and version[0] != cur_version[0]:
            return False
        return version <= cur_version
    else:
        return False

def getExcFileList(dir, cur_version):
     ret_list = []
     dir_list=os.listdir(dir)
     for fname in dir_list:
         if fname.endswith('.py'):
             version = parseVersion(fname)
             if isVersionLessOrEqual(version, cur_version):
             #if version <= cur_version:
                 file_path = os.path.join(dir, fname)
                 ret_list.append((version, file_path))
     return ret_list

def includeExc(release, arch, up_to_version):
    if not (release and os.path.exists(release)):
        return

    common_dir = os.path.join(release, 'common')
    arch_dir = os.path.join(release, arch)

    update_list_common = getExcFileList(common_dir, up_to_version)
    update_list_arch = getExcFileList(arch_dir, up_to_version)

    update_list = []
    update_list.extend(update_list_common)
    update_list.extend(update_list_arch)

    update_list = sorted(update_list)

    for (version, update_file_path) in update_list:
        print('Including: ', update_file_path, 'Version:', version)
        py_mod = imp.load_source(arch, update_file_path)
        py_mod.setup(exc)
        for header in exc:
            if len(exc[header]) < 4:
                exc[header] = exc[header] + (update_file_path,)

def getExc(header):
    if header in exc:
        return exc[header]
    return None

def makeHeaderList():
    global headers_root_dir
    print('Making header list')

    if not os.path.isdir(test_dir):
        os.makedirs(test_dir)

    header_list_file = os.path.join(test_dir, 'headers.txt')

    if headers_root_dir:
        hfile = open(header_list_file, 'w')
        for root, dirs, files in os.walk(headers_root_dir):
            for one_file in files:
                hfile.write(os.path.join(root, one_file)+'\n')
        hfile.close()
        pass
    else:
        headers_root_dir = '/usr/include/'

        try:
            header_file = open(header_list_file, 'w')
        except IOError:
            print("I/O Error: could not write to %s" % (header_list_file))
            sys.exit("Aborting test\n")

        rts = rpm.TransactionSet()
        rpmPkgList = rts.dbMatch('Provides', 'kernel-headers')
        try:
            hdr = next(rpmPkgList)
        except StopIteration:
            print("RPM Error: nothing provides kernel-headers")
            sys.exit("Aborting test\n")
        print('generating header list from %s package' % (hdr['name'].decode('UTF-8')))
        for name in sorted(hdr['FILENAMES']):
            header_file.write("%s\n" % name.decode('UTF-8'))

        header_file.close()

    header_file = open(header_list_file, 'r')
    for header in header_file:
        header = header.strip()

        if os.path.isfile(header) and header.startswith(headers_root_dir):
            include = header[len(headers_root_dir):]
            while include.startswith('/'):
                include = include[1:]
            header_list.append(include)
        else:
            print('Not a header', header, 'isfile:',  os.path.isfile(header))

def makeTestName(header, variant = None):
    testname = 'test-' + os.path.basename(os.path.dirname(header)) + '_' + os.path.basename(header)
    if variant:
        testname += '_' + variant
    testname += '.c'
    return testname

def makeTest(testname, header, extra = None, flags = None, comment = None):
    test_file = open(os.path.join(test_dir, testname), 'w')
    test_file.write('/* Test of header: %s */\n' % header)

    if extra:
        test_file.write('/* Extra: %s */\n' % ', '.join(extra))
    else:
        extra = []

    if flags is not None:
        test_file.write('/* Flags: %s */\n' % flags)
    else:
        flags = OK

    if comment:
        test_file.write('/* Comment: %s */\n' % comment)
    else:
        comment = ''

    if flags & (WARN | INFO):
        test_file.write('#warning <%s>\n' % comment)

    for action in extra:
        if action.startswith('* '):
            test_file.write('%s\n' % action[2:])
        else:
            test_file.write('#include <%s>\n' % action)

    if not flags & BLACKLIST:
        test_file.write('#include <%s>\n' % header)
    else:
        test_file.write('#warning this header was blacklisted: %s\n' % header)

    test_file.close()

def makeTestsVerify():
    print('Making tests')
    for header in header_list:
        exc_tuple = getExc(header)

        if exc_tuple:
            (extra, flags, comment, exc_file) = exc_tuple
            print('Header:', header)
            print('File:', exc_file)
            print('Extra:', extra)
            print('Flags:', flags)
            print('Comment:', comment)

            v_count = (1 << len(extra)) - 1
            if flags & BLACKLIST:
                print('Clearing BLACKLIST flag')
                flags &= ~BLACKLIST
                v_count += 1

            for v_val in range(0, v_count):

                v_extra = []
                v_mask = 1
                v_name = ''
                for v_act in extra:
                    if v_val & v_mask:
                        v_extra.append(v_act)
                        v_name += 'Y'
                    else:
                        v_name += 'n'
                    v_mask <<= 1

                print('Generating test file for header: %s (variant %d/%d %s)' % (header, v_val, v_count, v_name))
                testname = makeTestName(header, v_name)
                makeTest(testname, header, v_extra, flags, comment)
                test_list.append(testname)

        else:
            print('Skipping header:', header)

def makeTests():
    print('Making tests')
    for header in header_list:
        print('Generating test file for header:', header)
        testname = makeTestName(header)
        test_list.append(testname)

        exc_tuple = getExc(header)
        if exc_tuple:
            (extra, flags, comment, exc_file) = exc_tuple
            makeTest(testname, header, extra, flags, comment)
        else:
            makeTest(testname, header)

def makeCompileScript():
    print('Making compile script')
    scriptname = 'compile.sh'
    scriptname_path = os.path.join(test_dir, scriptname)
    script_file = open(scriptname_path, 'w')
    preamble = '#!/bin/sh\n' + \
        'echo "Kernel header test"\n\n' +\
        'echo Cleaning up old .o files\n' + \
        'rm -f *.o\n' + \
        'all_ok=true\n' + \
        'CFLAGS="-O0 -Wall -I%s" \n' % headers_root_dir + \
        'echo\n\n'
    script_file.write(preamble)

    def makeCompileCommands(testname):
        ret = 'echo "Compiling: %s"\n' % testname + \
            'echo "gcc -c $CFLAGS %s" \n' % testname + \
            'gcc -c $CFLAGS %s \n' % testname + \
            'ret=$?\n' + \
            'if [ $ret != 0 ]; then all_ok=false;' + \
            'echo "FAIL to compile: %s";' % testname + \
            'echo "----- cut -----";' + \
            'cat %s;' % testname + \
            'echo "----- cut -----";' + \
            'else echo "PASS: %s";' % testname + \
            'fi\n' + \
            'echo\n\n'
        return ret

    for testname in test_list:
        lines = makeCompileCommands(testname)
        script_file.write(lines)
    script_file.write('if [ $all_ok == true ]; then echo "ALL OK"; exit 0;  else echo "FAILED"; exit 1; fi\n')
    script_file.close()

    os.chmod(scriptname_path, stat.S_IRWXG | stat.S_IRWXU | stat.S_IXOTH | stat.S_IROTH)

def makeMakefile():
    print('Making makefile')
    scriptname = 'makefile'
    scriptname_path = os.path.join(test_dir, scriptname)

    script_file = open(scriptname_path, 'w')
    script_file.write('CC=gcc\n')
    script_file.write('CFLAGS=-O0 -Wall\n')
    script_file.write('all: \\\n')
    for header in header_list:
        testname = makeTestName(header)
        testname = testname[:-1] + 'o'
        script_file.write('\t%s \\\n' % testname)
    script_file.write('\n\n')
    script_file.close()

    os.chmod(scriptname_path, stat.S_IRWXG | stat.S_IRWXU | stat.S_IXOTH | stat.S_IROTH)


def main():
    global test_dir
    global header_list_file
    global headers_root_dir

    my_dir = os.path.dirname(__file__)
    if (my_dir):
        print('my_dir: ', my_dir)
        os.chdir(my_dir)

    if len(sys.argv) > 1:
        test_dir = sys.argv[1]
    if len(sys.argv) > 2:
        headers_root_dir = sys.argv[2]
    print('test_dir set to:', test_dir)
    print('headers_root_dir set to:', headers_root_dir)

    current_arch = getArch()
    current_release = getRelease()
    current_version = getVersion()
    print('arch is:', current_arch)
    print('release is:', current_release)
    print('version is:', current_version)

    if len(sys.argv) > 3:
        kernel_version_override = sys.argv[3]
        print('overriding kernel version to:', kernel_version_override)
        current_version = parseVersion(kernel_version_override)
        print('version is (overriden to):', current_version)

    includeExc(current_release, current_arch, current_version)

    makeHeaderList()
    if verify:
        makeTestsVerify()
    else:
        makeTests()
    makeCompileScript()
    print(os.path.basename(__file__), 'finished')

if __name__ == '__main__':
    main()
