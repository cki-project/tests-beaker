### common 4.18.0-0.el8 ########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'
    SA_FAMILY_T = "sys/socket.h"
    SOCKADDR = 'sys/socket.h'

    exc['asm-generic/ipcbuf.h'] = (['linux/posix_types.h'],
                                   OK, '__kernel_key_t')

    exc['asm-generic/msgbuf.h'] = (['linux/posix_types.h', 'asm-generic/ipcbuf.h'],
                                   OK, 'ipc64_perm __kernel_time_t')

    exc['asm-generic/sembuf.h'] = (['linux/posix_types.h', 'asm-generic/ipcbuf.h'],
                                   OK, 'ipc64_perm __kernel_time_t')

    exc['asm-generic/shmbuf.h'] = ([SIZE_T, 'linux/posix_types.h', 'asm-generic/ipcbuf.h'],
                                   OK, 'ipc64_perm __kernel_time_t size_t')

    exc['asm-generic/signal.h'] = ([SIZE_T],
                                   OK, 'size_t')

    exc['asm-generic/ucontext.h'] = ([SIZE_T, 'asm-generic/signal.h', 'asm/sigcontext.h'],
                                     OK, 'stack_t sigcontext')

    exc['asm/ipcbuf.h'] = (['linux/posix_types.h'],
                           OK, '__kernel_key_t')

    exc['asm/msgbuf.h'] = (['linux/posix_types.h', 'asm-generic/ipcbuf.h'],
                           OK, 'msg_perm, __kernel_time_t')

    exc['asm/sembuf.h'] = (['linux/sem.h'],
                           OK, '__kernel_time_t sem_perm')

    exc['asm/shmbuf.h'] = (['linux/shm.h'], OK, 'shm_perm')

    exc['asm/signal.h'] = ([SIZE_T], OK, 'size_t')

    exc['asm/stat.h'] = (['sys/types.h'],
                         OK, 'ino_t nlink_t mode_t uid_t gid_t off_t')

    exc['asm/ucontext.h'] = ([SIZE_T, 'asm/signal.h', 'asm/sigcontext.h'],
                             OK, 'stack_t sigcontext')

    exc['drm/vmwgfx_drm.h'] = ([], WARN | BLACKLIST,
                               'SVGA3dMSPattern and SVGA3dMSQualityLevel not defined in UAPI')

    exc['linux/android/binder.h'] = ([PID_T],
                                     OK, 'pid_t uid_t')

    exc['linux/coda.h'] = (['sys/types.h', '* #define _LINUX_TIME_H'],
                           OK | WARN, 'u_short pid_t ino_t caddr_t  u_short, sys/types conflicts with linux/time.h included by coda.h')

    exc['linux/coda_psdev.h'] = (['* struct list_head {};', '* typedef void* wait_queue_head_t;', 'sys/types.h'],
                                 OK | WARN, 'linux/coda_psdev.h - struct wait_queue_head_t not present anywhere')

    exc['linux/elfcore.h'] = ([
                               """* #include <stddef.h>
                                    #include <unistd.h>
                                    #define ELF_NGREG 1
                                    struct dummy {};
                                    typedef struct dummy elf_greg_t;
                                    typedef struct dummy elf_gregset_t;
                                    typedef struct dummy elf_fpregset_t;
                                    typedef struct dummy elf_fpxregset_t;"""
                               ], OK | WARN,
                              'user_regs_struct, size_t, pid_t, elf_greg_t, elf_gregset_t, elf_fpregset_t, elf_fpxregset_t')

    exc['linux/errqueue.h'] = (['linux/time.h'], OK, 'timespec')

    exc['linux/fsmap.h'] = ([SIZE_T], OK, 'size_t')

    exc['linux/hdlc/ioctl.h'] = ([SOCKADDR, 'linux/if.h'],
                                 OK, 'IFNAMSIZ')

    exc['linux/kexec.h'] = ([SIZE_T],
                               OK, 'size_t')

    exc['linux/netfilter_bridge/ebtables.h'] = ([SOCKADDR, 'stdint.h',
                                                'linux/in.h', 'linux/in6.h', 'linux/if.h'],
                                                OK, 'sockaddr inaddr in6addr uint64_t')

    exc['linux/netfilter/nf_osf.h'] = (['linux/ip.h', 'linux/tcp.h'],
                                       OK, 'MAX_IPOPTLEN iphdr tcphdr')

    exc['linux/ndctl.h'] = (['* #define PAGE_SIZE (1UL << 12)'],
                            OK, 'PAGE_SIZE')

    exc['linux/nfc.h'] = ([SA_FAMILY_T],
                          OK, 'sa_family_t size_t')

    exc['linux/omapfb.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/patchkey.h'] = ([SIZE_T],
                               WARN | BLACKLIST, 'error: #error "patchkey.h included directly"')

    exc['linux/phonet.h'] = ([SOCKADDR],
                             OK, 'sa_family_t sockaddr')

    exc['linux/reiserfs_xattr.h'] = ([SIZE_T],
                                     OK, 'size_t')

    exc['linux/scc.h'] = (['linux/sockios.h'],
                          OK, 'SIOCDEVPRIVATE')

    exc['linux/sctp.h'] = (['stdint.h', 'sys/socket.h'],
                           OK, 'uint32_t')

    exc['linux/signal.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/sysctl.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/usb/audio.h'] = (['stddef.h'],
                                OK, 'NULL')

    exc['linux/vm_sockets.h'] = ([SOCKADDR],
                                 OK, 'sockaddr sa_family_t')

    exc['scsi/scsi_bsg_fc.h'] = (['stdint.h'],
                                 OK, 'uint32_t')

    exc['scsi/scsi_netlink.h'] = (['stdint.h'],
                                  OK, 'uint32_t')

    exc['scsi/scsi_netlink_fc.h'] = (['stdint.h'],
                                     OK, 'uint32_t')

    exc['sound/skl-tplg-interface.h'] = (['''* #include <linux/types.h>
                                               typedef __u8  u8;
                                               typedef __u16 u16;
                                               typedef __u32 u32;
                                          '''],
                                         OK, 'u8 u16 u32 (fixed upstream in commit fb504caae7ef')

    exc['xen/evtchn.h'] = ([],
                           BLACKLIST | WARN, 'no domid_t')

    exc['xen/gntdev.h'] = ([],
                           BLACKLIST | WARN, 'no domid_t nor grant_ref_t')

    exc['xen/privcmd.h'] = ([],
                            BLACKLIST | WARN, 'no domid_t')

    exc['sound/sof/eq.h'] = (['stdint.h'], OK, 'int32_t uint32_t')

    exc['sound/sof/fw.h'] = (['stdint.h'], OK, 'int32_t uint32_t')

    exc['sound/sof/header.h'] = (['stdint.h'], OK, 'int32_t uint32_t')

    exc['sound/sof/manifest.h'] = (['stdint.h'], OK, 'int32_t uint32_t')

    exc['sound/sof/trace.h'] = (['stdint.h'], OK, 'int32_t uint32_t')
