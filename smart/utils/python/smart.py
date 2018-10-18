#!/usr/bin/python

from __future__ import print_function
import sys
import os
import subprocess


def print2(s):
    sys.stderr.write(s + '\n')


def get_workspace_root():
    this_file = os.path.realpath(__file__)
    this_root = os.path.dirname(this_file)
    l_ws_root = this_root.split(os.path.sep)
    l_ws_root.extend('../../../'.split('/'))
    s_ws_root = os.path.sep.join(l_ws_root)
    return os.path.realpath(s_ws_root)


class Cstr(object):
    """ Cstr(object) -> Colorful string

        o none    :  0 : '%s' % str
        o gray    : 30 : '\033[1;30m%s\033[m' % str
        o red     : 31 : '\033[1;31m%s\033[m' % str
        o green   : 32 : '\033[1;32m%s\033[m' % str
        o yellow  : 33 : '\033[1;33m%s\033[m' % str
        o blue    : 34 : '\033[1;34m%s\033[m' % str
        o magenta : 35 : '\033[1;35m%s\033[m' % str
        o cyan    : 36 : '\033[1;36m%s\033[m' % str
        o white   : 37 : '\033[1;37m%s\033[m' % str

        Return a colorful string representation of the object.

        Example:
        (1) print Cstr('Hello World', 'RED')
        (2) print Cstr('Hello World')
        (3) print Cstr()
    """
    def __init__(self, s='', color='none'):
        self.color = color
        self.ts = s
        self.cs = self.__get_color_str()

    def __str__(self):
        return self.cs

    def __len__(self):
        return len(self.ts)

    def __get_color_id(self):
        d_color = {
            'none':     0,
            'gray':    30,
            'red':     31,
            'green':   32,
            'yellow':  33,
            'blue':    34,
            'magenta': 35,
            'cyan':    36,
            'white':   37
        }
        color = self.color.lower()
        if color in d_color:
            return d_color[color]
        else:
            return d_color['none']

    def __get_color_str(self):
        cid = self.__get_color_id()
        if cid == 0:
            return self.ts

        if not self.__isatty():
            return self.ts

        return '\033[1;%dm%s\033[m' % (cid, self.ts)

    def __isatty(self):
        s = os.getenv('ISATTY')
        if s is None:
            s = ''

        if s.upper() == 'YES':
            return True

        if s.upper() == 'NO':
            return False

        if sys.stdout.isatty() and sys.stderr.isatty():
            return True

        return False


class Cmd(object):
    def __init__(self, cmd):
        self.cmd = cmd
        self.stdout = ''
        self.stderr = ''
        self.return_code = None

    def get_stdout(self):
        return self.stdout

    def get_stderr(self):
        return self.stderr

    def get_return_code(self):
        return self.return_code

    def execute(self):
        p = subprocess.Popen(self.cmd, shell=True,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        (self.stdout, self.stderr) = p.communicate()
        self.return_code = p.returncode
