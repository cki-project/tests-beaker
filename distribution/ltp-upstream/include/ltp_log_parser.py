#!/usr/bin/python3
""" A simple utility to parse test log of LTP """

import sys
import getopt
from itertools import groupby
import re

TC_START = "<<<test_start>>>"
TC_END = "<<<test_end>>>"
TC_NAME_FLAG = "tag="
TC_RESULT_FLAG = r'termination_type=exited\s+termination_id=\d+'
#
# XXX: Right here we define some result code according to source file:
# https://github.com/linux-test-project/ltp/blob/master/include/tst_res_flags.h
# /* Use low 6 bits to encode test type */
# #define TTYPE_MASK	0x3f
# #define TPASS	0	/* Test passed flag */
# #define TFAIL	1	/* Test failed flag */
# #define TBROK	2	/* Test broken flag */
# #define TWARN	4	/* Test warning flag */
# #define TINFO	16	/* Test information flag */
# #define TCONF	32	/* Test not appropriate for configuration flag */
# #define TTYPE_RESULT(ttype) ((ttype) & TTYPE_MASK)
#
TTYPE_MASK = 0x3f
TPASS = 0
TFAIL = 1
TBROK = 2
TWARN = 4
TINFO = 16
TCONF = 32
TC_LOG_OUTPUT_INDENT = 4
TC_LOG_SUMMARY_WIDTH = 79
TC_LOG_OUTPUT_RAW = False


def get_tc_name(l_tc):
    tc_name = "XXX-UNKNOWN-TEST-CASE"
    for text in l_tc:
        text = text.strip().rstrip()
        if text.startswith(TC_NAME_FLAG):
            tc_name = text.split(' ')[0].split('=')[1]
            break
    return tc_name


def get_tc_term_id(l_tc):
    term_id = TPASS
    l_res = []
    for text in l_tc:
        text = text.strip().rstrip()
        l_res = re.findall(TC_RESULT_FLAG, text)
        if l_res:
            break
    if l_res:
        s = l_res[0].split('=')[-1]
        term_id = int(s)
    return term_id


def get_tc_result(l_tc):
    term_id = get_tc_term_id(l_tc)

    tc_result = "PASS"
    rc = term_id & TTYPE_MASK
    if rc & TFAIL != 0:
        tc_result = "FAIL"
    elif rc & TBROK != 0:
        tc_result = "BROK"
    elif rc & TWARN != 0:
        tc_result = "WARN"
    elif rc & TCONF != 0:
        tc_result = "CONF"

    return tc_result


def fmt_text(text, width):
    return "# {} #".format(text.ljust(width - 4))


def print_summary(tcno, name, result):
    width = TC_LOG_SUMMARY_WIDTH
    print('#' * width)
    print(fmt_text("Test Num    : {}".format(tcno), width))
    print(fmt_text("Test Case   : {}".format(name), width))
    print(fmt_text("Test Result : {}".format(result), width))
    print('#' * width)
    print()


def print_refined_text(l_tc, spaces):
    groups = [(k, len(list(group))) for k, group in groupby(l_tc)]
    result, lineno = [], 1
    for line, count in groups:
        print("{}{:>6}\t{}".format(spaces, lineno, line))

        if count == 2:
            print("{}{:>6}\t{}".format(spaces, lineno + 1, line))
        elif count > 2:
            print("{}{}\t...<repeats {} times>...".format(
                spaces, " " * 6, count - 1)
            )

        lineno += count
    return result


def print_raw_text(l_tc, spaces):
    lineno = 0
    for line in l_tc:
        lineno += 1
        print("{}{:>6}\t{}".format(spaces, lineno, line))


def dump(d_tc_metadata, l_tc):
    tcno = d_tc_metadata['tcno']
    name = d_tc_metadata['name']
    result = d_tc_metadata['result']

    print(">>> {}:{} {} <<<".format(tcno, name, result))
    print_summary(tcno, name, result)
    if TC_LOG_OUTPUT_RAW:
        print_raw_text(l_tc, ' ' * TC_LOG_OUTPUT_INDENT)
    else:
        print_refined_text(l_tc, ' ' * TC_LOG_OUTPUT_INDENT)
    print()


def parse(file_handle):
    l_tcs = []
    while True:
        line = file_handle.readline()
        if not line:
            break

        line = line.strip().rstrip()
        if line.strip().startswith(TC_START):
            loop_flag = True
            l_tc = []
            l_tc.append(line)
            continue

        if line.strip().startswith(TC_END):
            loop_flag = False
            l_tc.append(line)
            l_tcs.append(l_tc)
            continue

        if loop_flag:
            l_tc.append(line)
    return l_tcs


def usage(prog):
    print("Usage: {} [-r] [-t indent] [-F] <logfile>".format(prog),
          file=sys.stderr)
    print("e.g.",
          file=sys.stderr)
    print("o dump failed test cases",
          file=sys.stderr)
    print("       {} -F /tmp/foo.log".format(prog),
          file=sys.stderr)
    print("o dump all test cases and remove those repeated lines",
          file=sys.stderr)
    print("       {} /tmp/foo.log".format(prog),
          file=sys.stderr)
    print("o dump all test cases without removing repeated lines",
          file=sys.stderr)
    print("       {} -r /tmp/foo.log".format(prog),
          file=sys.stderr)


def main(argc, argv):
    shortargs = ":Frt:"
    longargs = ["fail", "raw", "indent="]
    try:
        options, rargv = getopt.getopt(argv[1:], shortargs, longargs)
    except getopt.GetoptError as err:
        print("{}\n".format(str(err)), file=sys.stderr)
        usage(argv[0])
        return 1

    portion_flags = None
    for opt, arg in options:
        if opt in ("-F", "--fail"):
            portion_flags = ["FAIL", "BROK", "WARN"]
        elif opt in ("-r", "--raw"):
            global TC_LOG_OUTPUT_RAW
            TC_LOG_OUTPUT_RAW = True
        elif opt in ("-t", "--indent"):
            global TC_LOG_OUTPUT_INDENT
            TC_LOG_OUTPUT_INDENT = int(arg)
        else:
            usage(argv[0])
            return 1

    rargc = len(rargv)
    if rargc < 1:
        usage(argv[0])
        return 1

    logfile = rargv[0]
    with open(logfile, 'r') as file_handle:
        l_tcs = parse(file_handle)

    tcno = 0
    for l_tc in l_tcs:
        tcno += 1
        d_tc_metadata = {
            'tcno': tcno,
            'name': get_tc_name(l_tc),
            'result': get_tc_result(l_tc),
        }

        # Dump test log of all test cases by default
        if portion_flags is None:
            dump(d_tc_metadata, l_tc)
            continue

        #
        # Dump test log of those test cases regared as 'FAIL' by beaker
        # Here is the map between 'PASS/FAIL' from beaker's perspective and
        # 'TPASS/TFAIL/TBROK/TWARN/TINFO/TCONF' from  ltp's perspective:
        # o 'PASS': ['TPASS', 'TINFO', 'TCONF']
        # o 'FAIL': ['TFAIL', 'TBROK', 'TWARN']
        #
        if d_tc_metadata['result'] in portion_flags:
            dump(d_tc_metadata, l_tc)

    return 0


if __name__ == '__main__':
    sys.exit(main(len(sys.argv), sys.argv))
