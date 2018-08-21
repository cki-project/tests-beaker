#!/usr/bin/python

from __future__ import print_function
import sys
import os
import json
import collections
import getopt
import urllib2
from smart import print2, Cstr, Cmd

g_debug = False


def debug_mline(s, prefix='DEBUG>', color='GRAY'):
    if not g_debug:
        return

    l = s.split('\n')
    for e in l:
        print2('%s %s' % (Cstr(prefix, color), Cstr(e, color)))


def get_bash_prefix():
    p = "bash"
    if g_debug:
        p = "export PS4='[${FUNCNAME}@${BASH_SOURCE}:${LINENO}|${SECONDS}]+ '"
        p += " && bash -x"
    return p


class Smart(object):
    def __init__(self, f_caselist):
        self.caselist = f_caselist
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

    def get_cases_bylayout(self, d_layout):
        l_cases = []
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
            for e in p['cases']:
                if e not in l_cases:
                    l_cases.append(e)

        debug_mline('%s\n' % str(l_cases))
        return l_cases

    def get_xml_view(self):
        d_layout = self.get_layout(self.config['layout'])
        if d_layout is None:
            return None

        l_cases_all = self.get_cases_bylayout(d_layout)
        if l_cases_all is None:
            return None

        with open(self.caselist, 'r') as f:
            l_lines = f.readlines()
        l_cases_sub = list(map(lambda e: e.rstrip(), l_lines))
        debug_mline('%s\n' % str(l_cases_sub))

        l_xml_view = []
        for e in l_cases_all:
            case = e['case']
            template = e['template']
            handler = e['handler']
            if case in l_cases_sub:
                ex = dict()
                ex['template'] = self.__insert_prefix(template)
                ex['handler'] = self.__insert_prefix(handler)
                if ex not in l_xml_view:
                    l_xml_view.append(ex)

        debug_mline('%s\n' % str(l_xml_view))
        return l_xml_view

    def retrieve_xml_pieces(self, s_handler, s_template):
        # get the text of handler
        text = self.__get_text_file(s_handler)
        if text is None:
            print2("Oops, fail to get %s" % s_handler)
            return None
        debug_mline(text)

        # save handler to local
        f_handler = '/tmp/%s.%d' % (os.path.basename(s_handler), os.getpid())
        with open(f_handler, 'w') as f:
            f.write(text)

        # run local handler and catch the output
        s_cmd = '%s %s %s' % (get_bash_prefix(), f_handler, s_template)
        debug_mline(s_cmd)
        proc = Cmd(s_cmd)
        proc.execute()
        rc = proc.get_return_code()
        if rc != 0:
            print2('Oops, failed to execute cmd "%s", rc=%d' % (s_cmd, rc))
            print2(proc.get_stdout())
            print2(proc.get_stderr())
            return None
        else:
            debug_mline(proc.get_stdout())
            debug_mline(proc.get_stderr())

        text = proc.get_stdout()

        # remove the local handler
        os.unlink(f_handler)

        return text

    def create_xml_pieces(self, l_xml_view):
        if len(l_xml_view) == 0:
            return 0

        f_out = self.config['output']
        if f_out is None:
            fd = sys.stdout
        else:
            fd = open(f_out, 'w+')

        for e in l_xml_view:
            handler = e['handler']
            template = e['template']

            if handler is None:
                s_xml = self.__get_text_file(template)
            else:
                s_xml = self.retrieve_xml_pieces(handler, template)

            if s_xml is None:
                print2('Oops, fail to get xml by (%s, %s)' %
                       (str(handler), template))
                return 1

            fd.write(s_xml)

        return 0


def usage(s):
    print2('Usage: %s [-d] [-o outfile] <-l layout_file> <caselist file>' %
           argv[0])


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
    if argc != 1:
        usage(argv[0])
        return 1
    f_caselist = rargv[0]

    smart = Smart(f_caselist)

    # set config including layout file, output file, etc.
    smart.set_cfg(layout=f_layout,
                  output=f_output,
                  debug=g_debug)

    # get xml view by scanning test case list
    l_xml_view = smart.get_xml_view()
    if l_xml_view is None:
        print2("Oops, fail to get xml view")
        return 1

    # create xml pieces according the xml view we got
    rc = smart.create_xml_pieces(l_xml_view)
    if rc != 0:
        print2("Oops, fail to get xml pieces")
        return 1

    return 0


if __name__ == '__main__':
    argv = sys.argv
    argc = len(argv)
    sys.exit(main(argc, argv))
