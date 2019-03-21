### common 4.14.0-0.el7 ########################################################
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

    exc['drm/drm.h'] = ([SIZE_T, 'stdint.h'],
                        OK, 'size_t uint32_t uint64_t')

    exc['drm/drm_mode.h'] = (['stdint.h'], OK, '__u32 __u64 uint32_t uint64_t')

    exc['drm/drm_sarea.h'] = ([SIZE_T, 'stdint.h'],
                              OK, 'size_t uint32_t uint64_t')

    exc['drm/exynos_drm.h'] = ([SIZE_T, 'stdint.h'],
                               OK, 'size_t uint32_t uint64_t')

    exc['drm/i810_drm.h'] = ([SIZE_T, 'stdint.h', 'drm/drm.h'],
                             OK, 'drm_clip_rect size_t uint32_t uint64_t')

    exc['drm/i915_drm.h'] = ([SIZE_T, 'stdint.h'],
                             OK, 'size_t uint32_t uint64_t')

    exc['drm/mga_drm.h'] = ([SIZE_T, 'stdint.h'],
                             OK, 'size_t uint32_t uint64_t')

    exc['drm/msm_drm.h'] = (['stdint.h'], OK, 'uint32_t uint64_t')

    exc['drm/nouveau_drm.h'] = (['stdint.h'], OK, 'uint32_t uint64_t')

    exc['drm/qxl_drm.h'] = (['stdint.h'], OK, 'uint32_t')

    exc['drm/r128_drm.h'] = exc['drm/i810_drm.h']

    exc['drm/radeon_drm.h'] = ([SIZE_T, 'stdint.h'], OK, 'size_t uint32_t uint64_t')

    exc['drm/savage_drm.h'] = exc['drm/i810_drm.h']

    exc['drm/sis_drm.h'] = ([], WARN | BLACKLIST,
                            'list_head not available')

    exc['drm/tegra_drm.h'] = ([SIZE_T, 'stdint.h'], OK, 'size_t uint32_t')

    exc['drm/via_drm.h'] = ([], WARN | BLACKLIST,
                            'nonexistent file in include: via_drmclient.h, blacklisted')

    exc['drm/vmwgfx_drm.h'] = ([SIZE_T, 'stdint.h'],
                             OK, 'size_t uint32_t uint64_t')

    exc['linux/agpgart.h'] = ([SIZE_T],
                              OK, 'size_t')

    exc['linux/android/binder.h'] = ([PID_T],
                                     OK, 'pid_t uid_t')

    exc['linux/atm_zatm.h'] = (['linux/time.h'],
                               OK, 'timeval')

    exc['linux/atmbr2684.h'] = ([SOCKADDR],
                                OK, 'sockaddr')

    exc['linux/auto_fs.h'] = (['linux/limits.h'],
                              OK, 'NAME_MAX')

    exc['linux/auto_fs4.h'] = exc['linux/auto_fs.h']

    exc['linux/btrfs.h'] = (['stddef.h'], OK, 'NULL')

    exc['linux/can/bcm.h'] = ([SA_FAMILY_T],
                              OK | INFO, 'timeval canid_t sa_family_t, linux/time.h conflicts with sys/time.h')

    exc['linux/coda.h'] = (['sys/types.h', '* #define _LINUX_TIME_H'],
                           OK | WARN, 'u_short pid_t ino_t caddr_t  u_short, sys/types conflicts with linux/time.h included by coda.h')

    exc['linux/coda_psdev.h'] = (['* struct list_head {};', '* typedef void* wait_queue_head_t;', 'sys/types.h'],
                                 OK | WARN, 'linux/coda_psdev.h - struct wait_queue_head_t not present anywhere')

    exc['linux/dlm_netlink.h'] = (['linux/dlmconstants.h'],
                                  OK, 'DLM_RESNAME_MAXLEN')

    exc['linux/dm-log-userspace.h'] = (['stdint.h'],
                                       OK, 'uint64_t')

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

    exc['linux/hdlc/ioctl.h'] = ([SOCKADDR, 'linux/if.h'],
                                 OK, 'IFNAMSIZ')

    exc['linux/hsi/hsi_char.h'] = (['stdint.h'], OK, 'uint32_t uint64_t')

    exc['linux/if.h'] = ([SOCKADDR],
                         OK, 'sockaddr')

    exc['linux/if_arp.h'] = ([SOCKADDR],
                             OK, 'sockaddr sa_family_t')

    exc['linux/if_bonding.h'] = ([SOCKADDR],
                                 OK, 'sockaddr')


    exc['linux/if_frad.h'] = ([SOCKADDR],
                              OK, 'sockaddr')


    exc['linux/if_pppol2tp.h'] = (['linux/in.h', 'linux/in6.h'],
                                  OK, 'sockaddr_in sockaddr_in6 sa_family_t')

    exc['linux/if_pppox.h'] = (['linux/in.h', 'linux/in6.h', SOCKADDR, 'linux/if.h'],
                               OK, 'sockaddr_in sockaddr_in6 sa_family_t ETH_ALEN IFNAMSIZ sockaddr')


    exc['linux/if_tunnel.h'] = ([SOCKADDR, 'linux/if.h', 'linux/ip.h', 'linux/in6.h'],
                                OK, 'IFNAMSIZ')

    exc['linux/ip6_tunnel.h'] = ([SOCKADDR, 'linux/if.h', 'linux/in6.h'],
                                 OK, 'IFNAMSIZ in6_addr')

    exc['linux/ipv6_route.h'] = (['linux/in6.h'],
                                 OK, 'in6_addr')

    exc['linux/kexec.h'] = ([SIZE_T],
                               OK, 'size_t')

    exc['linux/llc.h'] = ([SOCKADDR, 'linux/if.h'],
                          OK, 'sa_family_t IFHWADDRLEN')

    exc['linux/mroute.h'] = (['linux/in.h'],
                             OK, 'in_addr')

    exc['linux/mroute6.h'] = (['linux/in6.h'],
                              OK, 'sockaddr_in6 in6_addr')

    exc['linux/mqueue.h'] = (['linux/posix_types.h'], OK, '__kernel_long_t')

    exc['linux/ncp_fs.h'] = ([SIZE_T],
                             OK, 'sa_family_t, size_t')

    exc['linux/netdevice.h'] = ([SOCKADDR],
                                OK, 'sa_family_t sockaddr')

    exc['linux/netfilter.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                OK, 'in_addr in6_addr sa_family_t')

    exc['linux/netfilter/ipset/ip_set_bitmap.h'] = (['linux/netfilter/ipset/ip_set.h'],
                                                    OK, 'IPSET_ERR_TYPE_SPECIFIC')

    exc['linux/netfilter/ipset/ip_set_hash.h'] = exc['linux/netfilter/ipset/ip_set_bitmap.h']

    exc['linux/netfilter/ipset/ip_set_list.h'] = exc['linux/netfilter/ipset/ip_set_bitmap.h']

    exc['linux/netfilter/nf_conntrack_sctp.h'] = ([SIZE_T, 'linux/types.h'],
                                                  OK, '__be32 size_t')

    exc['linux/netfilter/nf_conntrack_tuple_common.h'] = ([SIZE_T, 'linux/types.h'],
                                                  OK, '__be16 size_t')

    exc['linux/netfilter/nf_nat.h'] = (['sys/types.h', 'linux/in.h', 'linux/in6.h'],
                                        OK, 'in in6 ')

    exc['linux/netfilter/xt_HMARK.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                         OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_RATEEST.h'] = ([SOCKADDR, 'linux/if.h'],
                                           OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_TEE.h'] = ([SOCKADDR, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                       OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_TPROXY.h'] = exc['linux/netfilter/xt_TEE.h']

    exc['linux/netfilter/xt_connlimit.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                             OK, 'nf_inet_addr __be32')

    exc['linux/netfilter/xt_conntrack.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                             OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_hashlimit.h'] = ([SOCKADDR, 'linux/if.h', 'linux/limits.h'],
                                             OK, 'IFNAMSIZ NAME_MAX')

    exc['linux/netfilter/xt_iprange.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                           OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_ipvs.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                           OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_mac.h'] = (['linux/if_ether.h'],
                                       OK, 'ETH_ALEN')

    exc['linux/netfilter/xt_osf.h'] = (['linux/ip.h', 'linux/tcp.h'],
                                       OK, 'MAX_IPOPTLEN iphdr tcphdr')

    exc['linux/netfilter/xt_physdev.h'] = ([SOCKADDR, 'linux/if.h'],
                                           OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_policy.h'] = (['linux/in.h', 'linux/in6.h'],
                                          OK, 'in_addr in6_addr sa_family_t')

    exc['linux/netfilter/xt_rateest.h'] = ([SOCKADDR, 'linux/if.h'],
                                           OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_recent.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                             OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_sctp.h'] = (['* typedef int bool;', '* #define true 1;', '* #define false 0;'],
                                        OK | WARN, 'bool true false not defined')


    exc['linux/netfilter_arp.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                    OK, 'in_addr in6_addr')

    exc['linux/netfilter_arp/arp_tables.h'] = ([SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h'],
                                               OK, 'in_addr in6_addr u_int8_t u_int16_t IFNAMSIZ')

    exc['linux/netfilter_arp/arpt_mangle.h'] = ([SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h'],
                                               OK, 'in_addr in6_addr u_int8_t u_int16_t IFNAMSIZ')

    exc['linux/netfilter_bridge.h'] = ([SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h'],
                                       OK, 'in_addr in6_addr u_int8_t u_int16_t IFNAMSIZ')

    exc['linux/netfilter_bridge/ebt_arp.h'] = (['linux/if_ether.h'],
                                               OK, '__be16 ETH_ALEN uint8_t')

    exc['linux/netfilter_bridge/ebt_arpreply.h'] = (['linux/if_ether.h'],
                                                    OK, 'ETH_ALEN')

    exc['linux/netfilter_bridge/ebt_ip6.h'] = (['linux/in6.h'], OK, '__be32 uint8_t')

    exc['linux/netfilter_bridge/ebt_nat.h'] = (['linux/if_ether.h'],
                                               OK, 'ETH_ALEN')

    exc['linux/netfilter_bridge/ebt_ulog.h'] = ([SIZE_T, 'stdint.h', SOCKADDR, 'linux/if.h'],
                                                OK | WARN, 'uint32_t  IFNAMSIZ timeval size_t timeval')

    exc['linux/netfilter_bridge/ebtables.h'] = ([SOCKADDR, 'stdint.h', 
                                                'linux/in.h', 'linux/in6.h', 'linux/if.h'],
                                                OK, 'sockaddr inaddr in6addr uint64_t')

    exc['linux/netfilter_decnet.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                       OK, 'INT_MIN')

    exc['linux/netfilter_ipv4.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                     OK, 'INT_MIN INT_MAX')

    exc['linux/netfilter_ipv4/ip_tables.h'] = ([SOCKADDR, 'linux/in.h', 'linux/in6.h', 'linux/if.h'],
                                               OK, 'in_addr in6_addr INT_MIN INT_MAX u_int16_t u_int8_t IFNAMSIZ')

    exc['linux/netfilter_ipv4/ipt_ULOG.h'] = ([SIZE_T, SOCKADDR, 'linux/if.h'],
                                              OK, 'size_t IFNAMSIZ')

    exc['linux/netfilter_ipv6.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                     OK, 'INT_MIN in_addr in6_addr')

    exc['linux/netfilter_ipv6/ip6_tables.h'] = ([SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h'],
                                                OK, 'INT_MIN in_addr in6_addr  u_int16_t u_int8_t IFNAMSIZ')

    exc['linux/netfilter_ipv6/ip6t_NPT.h'] = ([SIZE_T, 'linux/in.h', 'linux/in6.h'],
                                             OK, 'SIZE_T in in6')

    exc['linux/netfilter_ipv6/ip6t_rt.h'] = (['linux/in6.h'], OK, 'u_int32_t in6_addr')

    exc['linux/nfc.h'] = ([SA_FAMILY_T],
                                             OK, 'sa_family_t size_t')

    exc['linux/nfsd/cld.h'] = (['stdint.h'],
                             OK, 'uint8_t uint16_t uint32_t uint64_t')

    exc['linux/omapfb.h'] = ([SIZE_T],
                               OK, 'size_t')

    exc['linux/openvswitch.h'] = (['stdint.h'],
                                  OK, 'size_t uint32_t uint64_t')

    exc['linux/packet_diag.h'] = (['net/if_arp.h'], OK, 'MAX_ADDR_LEN')

    exc['linux/patchkey.h'] = ([SIZE_T],
                               WARN | BLACKLIST, 'error: #error "patchkey.h included directly"')

    exc['linux/phonet.h'] = ([SOCKADDR],
                             OK, 'sa_family_t sockaddr')


    exc['linux/rds.h'] = ([SOCKADDR, 'stdint.h'],
                             OK, 'sockaddr')

    exc['linux/reiserfs_xattr.h'] = ([SIZE_T],
                                     OK, 'size_t')

    exc['linux/route.h'] = ([SOCKADDR],
                            OK, 'sockaddr')

    exc['linux/scc.h'] = (['linux/sockios.h'],
                          OK, 'SIOCDEVPRIVATE')

    exc['linux/sctp.h'] = (['stdint.h', 'sys/socket.h'], OK, 'uint32_t')

    exc['linux/signal.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/sysctl.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/target_core_user.h'] = (['stdint.h'],
                                       OK, 'size_t uint32_t uint64_t')

    exc['linux/vm_sockets.h'] = ([SOCKADDR],
                                 OK, 'sockaddr sa_family_t')

    exc['linux/wireless.h'] = ([SOCKADDR],
                               OK, 'sockaddr')

    exc['rdma/rdma_user_cm.h'] = (['sys/socket.h'], OK, 'sockaddr_storage')

    exc['scsi/scsi_bsg_fc.h'] = (['stdint.h'], OK, 'uint32_t')

    exc['scsi/scsi_netlink.h'] = (['stdint.h'], OK, 'uint32_t')

    exc['scsi/scsi_netlink_fc.h'] = (['stdint.h'], OK, 'uint32_t')


    exc['sound/emu10k1.h'] = (['* #define DECLARE_BITMAP(name,bits) unsigned long name[bits/8];'],
                              OK | WARN, 'DECLARE_BITMAPS - missing')

    exc['xen/gntalloc.h'] = (['stdint.h'], OK, 'uint32_t uint64_t')

    exc['xen/privcmd.h'] = ([], BLACKLIST | WARN, 'no domid_t')


    exc['asm/ucontext.h'] = ([SIZE_T, 'asm/signal.h', 'asm/sigcontext.h'],
                                     OK, 'stack_t sigcontext')

    exc['linux/hsi/cs-protocol.h'] = (['linux/time.h'], OK, 'timespec')

    exc['linux/virtio_balloon.h'] = (['linux/virtio_types.h'], OK, '__virtio16 __virtio64')

    exc['linux/gsmmux.h'] = ([SOCKADDR, 'linux/if.h'],
                             OK, 'sockaddr')

    exc['drm/virtgpu_drm.h'] = (['stdint.h'], OK, 'uint32_t uint64_t')

    exc['linux/virtio_gpu.h'] = (['stdint.h'], OK, 'uint8_t')

    exc['xen/gntdev.h'] = ([], BLACKLIST | WARN, 'no domid_t')

    exc['asm/stat.h'] = (['sys/types.h'],
                         OK, 'ino_t nlink_t mode_t uid_t gid_t off_t')

    exc['rdma/rdma_user_rxe.h'] = ([SOCKADDR, 'linux/in.h', 'linux/in6.h'],
                                   OK, 'sockaddr sockaddr_in sockaddr_in6')

    exc['sound/asoc.h'] = ([], WARN | BLACKLIST,
                           'sound/asoc.h is blacklisted in kernel 4.8.0')

    exc['xen/evtchn.h'] = ([], BLACKLIST | WARN, 'no domid_t')

    exc['linux/bpf_perf_event.h'] = ([], WARN | BLACKLIST,
                                     'struct pt_regs is undefined in userspace kernel headers')

    exc['rdma/mlx5-abi.h'] = (['linux/if_ether.h'], OK, 'ETH_ALEN')

    exc['linux/fsmap.h'] = ([SIZE_T], OK, 'size_t')

    exc['linux/kfd_ioctl.h'] = ([SIZE_T, 'stdint.h'],
                                OK, 'uint8_t uint16_t uint32_t uint64_t')

    exc['linux/rxrpc.h'] = ([SA_FAMILY_T, SIZE_T, 'linux/types.h',
                            '* typedef __u16 u16;', '* typedef __u64 u64;'],
                            OK, 'sa_family_t size_t')
