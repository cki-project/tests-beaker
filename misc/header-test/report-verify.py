#!/bin/python

from __future__ import print_function
import os
import sys
import re

opt_pass = bool(len(sys.argv) > 1 and sys.argv[1] == '--pass')
header = {}

def log_load():
    h = None
    for line in sys.stdin:
        m = re.search('^(Header|File|Extra|Flags|Comment):\s*(.*)$', line.strip())
        if m and m.group(1) == 'Header':
            h = os.path.basename(os.path.dirname(m.group(2))) + '_' + os.path.basename(m.group(2))
            header[h] = { 'Header': m.group(2), 'Pass': [] }
        elif m and h is not None:
            header[h][m.group(1)] = m.group(2)
        else:
            m = re.search('^PASS:\s*test-(.*\.h)_([Yn]*).c$', line.strip())
            if m and m.group(1) in header:
                header[m.group(1)]['Pass'].append(m.group(2))
            else:
                m = re.search('^PASS:\s*test-(.*\.h).c$', line.strip())
                if m and m.group(1) in header:
                    header[m.group(1)]['Pass'].append('(blacklisted)')

def log_report():
    for h, l in sorted(header.items()):
        if not opt_pass or len(l['Pass']):
            for i in 'Header', 'File', 'Extra', 'Flags', 'Comment':
                print('%-8s: %s' % (i, l[i] if i in l else ''))
            for v in l['Pass']:
                print(v)
            print()

log_load()
log_report()
