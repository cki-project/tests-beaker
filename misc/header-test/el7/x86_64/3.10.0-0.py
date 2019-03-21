### x86_64 3.10.0-0.el7 ########################################################

from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'

    exc['asm/ucontext.h'] = ([SIZE_T, 'asm-generic/signal.h', 'asm/sigcontext.h'],
                             OK, 'stack_t uc_mcontext size_t')

    exc['asm/msr-index.h'] = ([], BLACKLIST | WARN, 'no linux/bits.h')
