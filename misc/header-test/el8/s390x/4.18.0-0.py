### s390x 4.18.0-0.el8 #########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'
    SA_FAMILY_T = "sys/socket.h"
    SOCKADDR = 'sys/socket.h'

    exc['asm/runtime_instr.h'] = (['* #define __aligned(x) __attribute__((aligned(x)))'],
                                  OK, '__aligned from linux/compiler-gcc.h')

    exc['asm/zcrypt.h'] = ([SIZE_T, 'stdint.h'],
                           OK, 'uint16_t uint32_t uint64_t')
