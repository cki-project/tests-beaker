### aarch64 4.14.0-0.el7 #######################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'
    SA_FAMILY_T = "sys/socket.h"
    SOCKADDR = 'sys/socket.h'
