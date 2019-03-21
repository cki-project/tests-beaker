### i686 2.6.32-0.el6 ##########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'

    exc['asm/ucontext.h'] = ([SIZE_T, 'asm-generic/signal.h', 'asm/sigcontext.h'],
                             OK, 'stack_t uc_mcontext size_t')
