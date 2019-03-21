### ppc64 3.10.0-0.el7 #########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'

    exc['asm/ucontext.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['asm/setup.h'] = ([], WARN | BLACKLIST,
                            'nonexistent types phys_addr_t gfp_t')

