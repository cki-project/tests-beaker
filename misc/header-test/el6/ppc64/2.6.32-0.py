### ppc64 2.6.32-0.el6 #########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'

    exc['asm/stat.h'] = (['sys/types.h'],
                         OK, 'ino_t')

    exc['asm/ucontext.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['asm/setup.h'] = (['* typedef _Bool bool;'],
                          OK, 'bool')
