#!/usr/bin/python

from __future__ import print_function
import sys
import os
import json
import collections
import getopt
import urllib2
import re
from smart import print2, Cstr

g_debug = False


def debug_mline(s, prefix='DEBUG>', color='GRAY'):
    if not g_debug:
        return

    l = s.split('\n')
    for e in l:
        print2('%s %s' % (Cstr(prefix, color), Cstr(e, color)))


class Smart(object):
    def __init__(self, l_patch):
        self.l_patch = l_patch
        self.config = None

    def set_cfg(self, **kwargs):
        self.config = kwargs
        debug_mline(str(self.config))

    def __insert_prefix(self, obj):
        if obj is None:
            return None
        prefix = os.path.dirname(os.path.realpath(self.config['layout']))
        return '%s/%s' % (prefix, str(obj))

    def __get_text_file(self, f_text):
        if f_text.startswith('http://') or f_text.startswith('ftp://'):
            debug_mline("Open URL %s ..." % f_text)

            req = urllib2.Request(f_text)
            try:
                rep = urllib2.urlopen(req)
            except Exception as e:
                print2("Oops, fail to get %s: %s" % (f_text, str(e)))
                return None

            text = rep.read()
        else:
            debug_mline("Load file %s ..." % f_text)

            with open(f_text, 'r') as f:
                text = ''.join(f.readlines())

        return text

    def get_layout(self, f_layout):
        text = self.__get_text_file(f_layout)
        if text is None:
            print2('Oops, fail to get layout %s' % f_layout)
            return None

        debug_mline(text)
        layout = json.loads(text, object_pairs_hook=collections.OrderedDict)
        return layout

    def get_patterns_bylayout(self, d_layout):
        l_patterns = []
        for key in d_layout:
            val = d_layout[key]
            if val is None:
                continue

            s_file = self.__insert_prefix(val)
            text = self.__get_text_file(s_file)
            if text is None:
                print2("Oops, fail to get %s" % s_file)
                continue  # ?? raise ERROR ??

            debug_mline(text)
            p = json.loads(text, object_pairs_hook=collections.OrderedDict)
            for e in p['patterns']:
                if e not in l_patterns:
                    l_patterns.append(e)

        return l_patterns

    def get_src_files(self):
        """ Get source files according to patch file

            N.B. Typical source files shown in patch file look like:
                 diff --git a/fs/btrfs/ctree.h b/fs/btrfs/ctree.h
                 diff --git a/fs/btrfs/file.c b/fs/btrfs/file.c
                 ...
        """
        p = re.compile(r'^diff --git a/.* b/.*')

        l_src = []
        for f_patch in self.l_patch:
            with open(f_patch, 'r') as f:
                while True:
                    line = f.readline()
                    if len(line) == 0:
                        break

                    if p.match(line.strip()) is None:
                        continue

                    line = line.rstrip()
                    debug_mline(line)
                    l_line = line.split(' ')
                    srcfile = l_line[-1].replace('b/', '')
                    if srcfile not in l_src:
                        l_src.append(srcfile)

        debug_mline(str(l_src) + '\n')
        return l_src

    def get_cases(self, l_src):
        # get layout
        d_layout = self.get_layout(self.config['layout'])
        if d_layout is None:
            print2('Oops, fail to get layout')
            return None

        # get patterns by layout
        l_patterns = self.get_patterns_bylayout(d_layout)
        if l_patterns is None:
            print2('Oops, fail to get patterns')
            return None

        # get cases by patterns
        l_cases = []
        for e in l_patterns:
            pattern = e['pattern']
            case = e['case']

            p = re.compile(r'%s' % pattern)
            for f_src in l_src:
                ret = p.match(f_src)
                if ret is None:
                    debug_mline("%s: pattern r'%s' match '%s', case is '%s'" %
                                ('FAIL', pattern, f_src, case))
                    continue
                else:
                    debug_mline("%s: pattern r'%s' match '%s', case is '%s'" %
                                (Cstr('PASS', 'cyan'), pattern, f_src, case))

                if case in l_cases:
                    debug_mline("%s: case '%s' as it is duplicated" %
                                ('DROP', case))
                    continue
                else:
                    debug_mline("%s: case '%s'" % (Cstr('PICK', 'blue'), case))
                    l_cases.append(case)

        debug_mline(str(l_cases) + '\n')
        return l_cases

    def output_cases(self, l_cases):
        if len(l_cases) == 0:
            return

        f_out = self.config['output']
        if f_out is None:
            fd = sys.stdout
        else:
            fd = open(f_out, 'w+')

        for case in l_cases:
            fd.write('%s\n' % case)


def usage(s):
    print2('Usage: %s [-d] [-o outfile] <-l layout_file> '
           '<patch_file_1 [patch_file_2] ...>' % argv[0])


def main(argc, argv):
    f_layout = None
    f_output = None

    options, rargv = getopt.getopt(argv[1:],
                                   ':l:o:dh',
                                   ['layout=', 'output=',
                                    'debug', 'help'])
    for opt, arg in options:
        if opt in ('-d', '--debug'):
            global g_debug
            g_debug = True
        elif opt in ('-l', '--layout'):
            f_layout = arg
        elif opt in ('-o', '--output'):
            f_output = arg
        else:
            usage(argv[0])
            return 1

    if f_layout is None:
        usage(argv[0])
        return 1

    argc = len(rargv)
    if argc < 1:
        usage(argv[0])
        return 1

    l_patch = rargv
    smart = Smart(l_patch)

    # set config including layout file, output file, etc.
    smart.set_cfg(layout=f_layout,
                  output=f_output,
                  debug=g_debug)

    # get source files according to patch file
    l_srcfiles = smart.get_src_files()
    if len(l_srcfiles) == 0:
        # exit quietly since there is no source file updated
        return 0

    # get test cases according to source files
    l_cases = smart.get_cases(l_srcfiles)
    if l_cases is None:
        print2("Oops, fail to get test cases")
        return 1

    # output the cases
    smart.output_cases(l_cases)

    return 0


if __name__ == '__main__':
    argv = sys.argv
    argc = len(argv)
    sys.exit(main(argc, argv))
