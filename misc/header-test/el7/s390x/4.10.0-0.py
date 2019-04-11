### s390x 4.10.0-0.el7 #########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'
    SA_FAMILY_T = "sys/socket.h"
    SOCKADDR = 'sys/socket.h'

    exc['asm/zcrypt.h'] = ([SIZE_T, 'stdint.h'],
                           OK, 'uint16_t uint32_t uint64_t')
