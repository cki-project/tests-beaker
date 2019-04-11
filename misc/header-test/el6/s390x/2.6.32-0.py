### s390x 2.6.32-0.el6 #########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'

    exc['asm/chpid.h'] = (['linux/types.h', '* typedef __u8 u8;'],
                          OK | WARN, 'u8')
    exc['asm/chsc.h'] = (['sys/user.h', 'linux/types.h', '* typedef __u8 u8;'],
                         OK | WARN, 'PAGE_SIZE u8')
    exc['asm/ucontext.h'] = ([SIZE_T, 'asm-generic/signal.h', 'asm/sigcontext.h'],
                             OK, 'stack_t uc_mcontext size_t')

    exc['asm/zcrypt.h'] = ([SIZE_T, 'stdint.h'],
                           OK, 'uint16_t uint32_t uint64_t')
