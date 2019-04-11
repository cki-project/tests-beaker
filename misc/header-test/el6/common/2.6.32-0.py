### common 2.6.32-0.el6 ########################################################
from flags import *

def setup(exc):
    PID_T = 'unistd.h'
    SIZE_T = 'stddef.h'
    SA_FAMILY_T = "sys/socket.h"
    SOCKADDR = 'sys/socket.h'

    exc['drm/drm.h'] = ([SIZE_T, 'stdint.h'],
                        OK, 'size_t uint32_t')

    exc['drm/drm_mode.h'] = (['linux/types.h', 'stdint.h'],
                             OK, '__u32 __u64 uint32_t')

    exc['drm/drm_sarea.h'] = ([SIZE_T, 'stdint.h'],
                              OK, 'size_t uint32_t')

    exc['drm/i810_drm.h'] = ([SIZE_T, 'stdint.h', 'drm/drm.h'],
                             OK, 'drm_clip_rect size_t uint32_t')

    exc['drm/i915_drm.h'] = ([SIZE_T, 'stdint.h'],
                             OK, 'size_t uint32_t')

    exc['drm/mga_drm.h'] = ([SIZE_T, 'stdint.h', 'drm/drm.h'],
                             OK, 'drm_clip_rect size_t uint32_t')

    exc['drm/r128_drm.h'] = ([SIZE_T, 'stdint.h', 'drm/drm.h'],
                             OK, 'drm_clip_rect size_t uint32_t')

    exc['drm/savage_drm.h'] = ([SIZE_T, 'stdint.h', 'drm/drm.h'],
                               OK, 'drm_tex_region size_t uint32_t')

    exc['drm/nouveau_drm.h'] = (['stdint.h'],
                                OK, 'uint32_t uint64_t')

    exc['drm/radeon_drm.h'] = ([SIZE_T, 'stdint.h', 'drm/drm.h'],
                               OK, 'uint32_t uint64_t drm_clip_rect size_t')

    exc['drm/via_drm.h'] = ([SIZE_T],
                            WARN | BLACKLIST, 'nonexistent file in include: via_drmclient.h, blacklisted')

    exc['linux/netfilter/xt_set.h'] = (['* typedef int ip_set_id_t;','* #define IPSET_DIM_MAX 1'],
                                            OK, 'ip_set_id_t IPSET_DIM_MAX')

    exc['linux/netfilter/ipset/ip_set_bitmap.h'] = (['linux/netfilter/ipset/ip_set.h'],
                                            OK, 'IPSET_ERR_TYPE_SPECIFIC')

    exc['linux/netfilter/ipset/ip_set_list.h'] = (['linux/netfilter/ipset/ip_set.h'],
                                            OK, 'IPSET_ERR_TYPE_SPECIFIC')

    exc['linux/netfilter/ipset/ip_set_hash.h'] = (['linux/netfilter/ipset/ip_set.h'],
                                            OK, 'IPSET_ERR_TYPE_SPECIFIC')

    exc['linux/if_bridge.h'] = ([], BLACKLIST | WARN, 'ip6 incomplete type')

    exc['rdma/rdma_user_cm.h'] = (['sys/socket.h'], OK, 'sockaddr_storage')

    exc['drm/sis_drm.h'] = ([], WARN | BLACKLIST,
                            'list_head not available')

    exc['linux/virtio_net.h'] = (['linux/types.h', '* typedef __u16 u16;', '* typedef __u64 u64;'],
                                 OK | WARN, 'u16 u64 not defined')

    exc['asm-generic/fcntl.h'] = ([PID_T],
                                  OK, 'pid_t')

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

    exc['asm/fcntl.h'] = ([PID_T],
                          OK, 'pid_t')

    exc['asm/ipcbuf.h'] = (['linux/posix_types.h'],
                           OK, '__kernel_key_t')

    exc['asm/msgbuf.h'] = (['linux/posix_types.h', 'asm-generic/ipcbuf.h'],
                           OK, 'msg_perm, __kernel_time_t')

    exc['asm/sembuf.h'] = (['linux/posix_types.h', 'linux/sem.h'],
                           OK, '__kernel_time_t sem_perm')

    exc['asm/shmbuf.h'] = ([SIZE_T, 'linux/shm.h'],
                           OK, 'shm_perm, SIZE_T')

    exc['asm/signal.h'] = ([SIZE_T],
                           OK, 'size_t')

    exc['asm/sigcontext32.h'] = (['* struct _fpx_sw_bytes {};'],
                                 OK | WARN, '_fpx_sw_bytes not defined')

    exc['drm/i830_drm.h'] = ([SIZE_T, 'drm/drm.h'],
                             OK, 'drm_clip_rect size_t')

    exc['linux/agpgart.h'] = ([SIZE_T],
                              OK, 'size_t')

    exc['linux/atalk.h'] = ([SA_FAMILY_T],
                            OK, 'sa_family_t')

    exc['linux/atm_zatm.h'] = (['linux/time.h'],
                               OK, 'timeval')

    exc['linux/atmbr2684.h'] = ([SOCKADDR],
                                OK, 'sockaddr')

    exc['linux/auto_fs.h'] = (['linux/limits.h'],
                              OK, 'NAME_MAX')

    exc['linux/auto_fs4.h'] = (['linux/limits.h'],
                               OK, 'NAME_MAX')

    exc['linux/ax25.h'] = ([SA_FAMILY_T],
                           OK, 'sa_family_t')

    exc['linux/can.h'] = ([SA_FAMILY_T],
                          OK, 'sa_family_t')

    exc['linux/can/bcm.h'] = ([SA_FAMILY_T, 'linux/can.h'],
                              OK | INFO, 'timeval canid_t sa_family_t, linux/time.h conflicts with sys/time.h')

    exc['linux/can/raw.h'] = ([SA_FAMILY_T],
                              OK, 'sa_family_t')

    exc['linux/coda.h'] = (['sys/types.h', '* #define _LINUX_TIME_H'],
                           OK | WARN, 'u_short pid_t ino_t caddr_t  u_short, sys/types conflicts with linux/time.h included by coda.h')

    exc['linux/coda_psdev.h'] = (['* struct list_head {};', '* typedef void* wait_queue_head_t;', 'sys/types.h', '* #define _LINUX_TIME_H', 'linux/coda.h'],
                                 OK | WARN, 'linux/coda_psdev.h - struct wait_queue_head_t not present anywhere')

    exc['linux/dlm_netlink.h'] = (['linux/dlmconstants.h'],
                                  OK, 'DLM_RESNAME_MAXLEN')

    exc['linux/dm-log-userspace.h'] = (['stdint.h'],
                                       OK, 'uint64_t')

    exc['linux/elf-fdpic.h'] = (['* struct elfhdr {};'],
                                OK | WARN, 'linux/elf-fdpic.h - struct elfhdr undefined')

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

    exc['linux/eventpoll.h'] = ([PID_T],
                                OK, 'pid_t')

    exc['linux/ext2_fs.h'] = (['linux/fs.h'],
                              OK, 'FS_DIRSYNC_FL, FS_TOPDIR_FL, FS_NODUMP_FL, FS_NOATIME_FL')

    exc['linux/fcntl.h'] = ([PID_T],
                            OK, 'pid_t')

    exc['linux/fib_rules.h'] = ([SA_FAMILY_T],
                                OK, 'sa_family_t')

    exc['linux/genetlink.h'] = ([SA_FAMILY_T],
                                OK, 'sa_family_t')

    exc['linux/hdlc/ioctl.h'] = ([SOCKADDR, 'linux/if.h'],
                                 OK, 'IFNAMSIZ')

    exc['linux/if.h'] = ([SOCKADDR],
                         OK, 'sockaddr')

    exc['linux/if_addr.h'] = ([SA_FAMILY_T],
                              OK, 'sa_family_t')

    exc['linux/if_arp.h'] = ([SA_FAMILY_T, SOCKADDR],
                             OK, 'sockaddr sa_family_t')

    exc['linux/if_bonding.h'] = ([SOCKADDR],
                                 OK, 'sockaddr')

    exc['linux/if_frad.h'] = ([SOCKADDR],
                              OK, 'sockaddr')

    exc['linux/if_link.h'] = ([SA_FAMILY_T],
                              OK, 'sa_family_t')

    exc['linux/if_ppp.h'] = (['* typedef unsigned long aligned_u64;', 'linux/ppp_defs.h', SOCKADDR, 'linux/if.h'],
                             OK | WARN, 'NPmode ifreq ppp_stats ppp_comp_stats aligned_u64')

    exc['linux/if_pppol2tp.h'] = ([SA_FAMILY_T, 'linux/in.h'],
                                  OK, 'sockaddr_in sa_family_t')

    exc['linux/if_pppox.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/if_ether.h', SOCKADDR, 'linux/if.h'],
                               OK, 'sockaddr_in sa_family_t ETH_ALEN IFNAMSIZ sockaddr')

    exc['linux/if_tunnel.h'] = ([SOCKADDR, 'linux/if.h', 'linux/ip.h'],
                                OK, 'IFNAMSIZ')

    exc['linux/in.h'] = ([SA_FAMILY_T],
                         OK, 'sa_family_t')

    exc['linux/inotify.h'] = ([PID_T],
                              OK, 'pid_t')

    exc['linux/ip6_tunnel.h'] = ([SOCKADDR, 'linux/if.h', 'linux/in6.h'],
                                 OK, 'IFNAMSIZ in6_addr')

    exc['linux/ipv6_route.h'] = (['linux/in6.h'],
                                 OK, 'in6_addr')

    exc['linux/ipx.h'] = ([SA_FAMILY_T],
                          OK, 'sa_family_t')

    exc['linux/irda.h'] = ([SA_FAMILY_T],
                           OK, 'sa_family_t')

    exc['linux/llc.h'] = ([SA_FAMILY_T, SOCKADDR, 'linux/if.h'],
                          OK, 'sa_family_t IFHWADDRLEN')

    exc['linux/mroute.h'] = ([SA_FAMILY_T, 'linux/in.h'],
                             OK, 'in_addr')

    exc['linux/mroute6.h'] = (['linux/in6.h'],
                              OK, 'sockaddr_in6 in6_addr')

    exc['linux/ncp_fs.h'] = ([SIZE_T, SA_FAMILY_T],
                             OK, 'sa_family_t, size_t')

    exc['linux/neighbour.h'] = ([SA_FAMILY_T],
                                OK, 'sa_family_t')

    exc['linux/net_dropmon.h'] = ([SA_FAMILY_T],
                                  OK, 'sa_family_t')

    exc['linux/netdevice.h'] = ([SA_FAMILY_T, SOCKADDR],
                                OK, 'sa_family_t sockaddr')

    exc['linux/netfilter.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                OK, 'in in6 in_addr in6_addr sa_family_t')

    exc['linux/netfilter/nf_conntrack_sctp.h'] = (['linux/types.h'],
                                                  OK, '__be32')

    exc['linux/netfilter/nfnetlink_log.h'] = (['* typedef unsigned long aligned_be64;'],
                                              OK | WARN, 'aligned_be64 not defined')

    exc['linux/netfilter/nfnetlink_queue.h'] = (['* typedef unsigned long aligned_be64;'],
                                                OK | WARN, 'aligned_be64 not defined')

    exc['linux/netfilter/xt_RATEEST.h'] = ([SOCKADDR, 'linux/if.h'],
                                           OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_TCPOPTSTRIP.h'] = (['sys/types.h'],
                                               OK, 'u_int32_t')

    exc['linux/netfilter/xt_TPROXY.h'] = (['linux/types.h', 'sys/types.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                          OK, 'u_int32_t __be32 nf_inet_addr')

    exc['linux/netfilter/xt_cluster.h'] = (['sys/types.h'],
                                           OK, 'u_int32_t')

    exc['linux/netfilter/xt_connbytes.h'] = (['* typedef unsigned long aligned_u64;'],
                                             OK | WARN, 'aligned_u64 not defined')

    exc['linux/netfilter/xt_connlimit.h'] = (['linux/types.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                             OK, 'nf_inet_addr __be32')

    exc['linux/netfilter/xt_conntrack.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                             OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_hashlimit.h'] = ([SOCKADDR, 'linux/if.h'],
                                             OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_iprange.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                           OK, 'nf_inet_addr')

    exc['linux/netfilter/xt_mac.h'] = (['linux/if_ether.h'],
                                       OK, 'ETH_ALEN')

    exc['linux/netfilter/xt_osf.h'] = (['linux/ip.h', 'linux/tcp.h'],
                                       OK, 'MAX_IPOPTLEN iphdr tcphdr')

    exc['linux/netfilter/xt_physdev.h'] = ([SOCKADDR, 'linux/if.h'],
                                           OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_policy.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                          OK, 'in_addr in6_addr sa_family_t')

    exc['linux/netfilter/xt_quota.h'] = (['sys/types.h', '* typedef unsigned long aligned_u64;'],
                                         OK | WARN, 'u_int32_t aligned_u64 not defined')

    exc['linux/netfilter/xt_rateest.h'] = ([SOCKADDR, 'linux/if.h'],
                                           OK, 'IFNAMSIZ')

    exc['linux/netfilter/xt_sctp.h'] = (['* typedef int bool;', '* #define true 1;', '* #define false 0;'],
                                        OK | WARN, 'bool true false not defined')

    exc['linux/netfilter/xt_time.h'] = (['sys/types.h'],
                                        OK, 'u_int32_t')

    exc['linux/netfilter/xt_u32.h'] = (['sys/types.h'],
                                       OK, 'u_int32_t u_int8_t')

    exc['linux/netfilter_arp.h'] = ([SA_FAMILY_T, 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                    OK, 'in_addr in6_addr')

    exc['linux/netfilter_arp/arp_tables.h'] = ([SA_FAMILY_T, 'sys/types.h', SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                               OK, 'in_addr in6_addr u_int8_t u_int16_t IFNAMSIZ')

    exc['linux/netfilter_arp/arpt_mangle.h'] = ([SA_FAMILY_T, 'sys/types.h', SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                                OK, 'in_addr in6_addr u_int8_t u_int16_t')

    exc['linux/netfilter_bridge.h'] = ([SA_FAMILY_T, 'sys/types.h', SOCKADDR, 'linux/if.h', 'linux/in.h', 'linux/in6.h', 'linux/netfilter.h'],
                                       OK, 'in_addr in6_addr u_int8_t u_int16_t IFNAMSIZ')

    exc['linux/netfilter_bridge/ebt_802_3.h'] = (['stdint.h', 'linux/types.h'],
                                                 OK, 'u_int8_t __be16')

    exc['linux/netfilter_bridge/ebt_among.h'] = (['stdint.h', 'linux/types.h'],
                                                 OK, 'uint32_t __be32')

    exc['linux/netfilter_bridge/ebt_arp.h'] = (['stdint.h', 'linux/types.h', 'linux/if_ether.h'],
                                               OK, '__be16 ETH_ALEN uint8_t')

    exc['linux/netfilter_bridge/ebt_arpreply.h'] = (['linux/if_ether.h'],
                                                    OK, 'ETH_ALEN')

    exc['linux/netfilter_bridge/ebt_ip.h'] = (['stdint.h', 'linux/types.h'],
                                              OK, '__be32 uint8_t')

    exc['linux/netfilter_bridge/ebt_limit.h'] = (['sys/types.h'],
                                                 OK, 'u_int32_t')

    exc['linux/netfilter_bridge/ebt_log.h'] = (['stdint.h'],
                                               OK, 'uint8_t')

    exc['linux/netfilter_bridge/ebt_mark_m.h'] = (['stdint.h'],
                                                  OK, 'uint8_t')

    exc['linux/netfilter_bridge/ebt_nat.h'] = (['linux/if_ether.h'],
                                               OK, 'ETH_ALEN')

    exc['linux/netfilter_bridge/ebt_pkttype.h'] = (['stdint.h'],
                                                   OK, 'uint8_t')

    exc['linux/netfilter_bridge/ebt_stp.h'] = (['stdint.h'],
                                               OK, 'uint8_t')

    exc['linux/netfilter_bridge/ebt_ulog.h'] = ([SIZE_T, 'stdint.h', SOCKADDR, 'linux/if.h'],
                                                OK | WARN, 'uint32_t  IFNAMSIZ timeval size_t timeval')

    exc['linux/netfilter_bridge/ebt_vlan.h'] = (['stdint.h', 'linux/types.h'],
                                                OK, 'uint16_t uint8_t __be16')

    exc['linux/netfilter_bridge/ebtables.h'] = ([SOCKADDR, 'stdint.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                                OK, 'sockaddr inaddr in6addr uint64_t')

    exc['linux/netfilter_decnet.h'] = (['limits.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                       OK, 'INT_MIN')

    exc['linux/netfilter_ipv4.h'] = (['limits.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                     OK, 'INT_MIN INT_MAX')

    exc['linux/netfilter_ipv4/ip_queue.h'] = (['linux/types.h'],
                                              OK, '__be16')

    exc['linux/netfilter_ipv4/ip_tables.h'] = (['sys/types.h', 'limits.h', SA_FAMILY_T, SOCKADDR, 'linux/in.h', 'linux/in6.h', 'linux/if.h'],
                                               OK, 'in_addr in6_addr INT_MIN INT_MAX u_int16_t u_int8_t IFNAMSIZ')

    exc['linux/netfilter_ipv4/ipt_CLUSTERIP.h'] = (['sys/types.h'],
                                                   OK, 'u_int32_t')

    exc['linux/netfilter_ipv4/ipt_ECN.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv4/ipt_SAME.h'] = (['* struct nf_nat_range {};', 'sys/types.h'],
                                              OK | WARN, 'u_int32_t nf_nat_range missing')

    exc['linux/netfilter_ipv4/ipt_TTL.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv4/ipt_ULOG.h'] = ([SIZE_T, SOCKADDR, 'linux/if.h'],
                                              OK, 'size_t IFNAMSIZ')

    exc['linux/netfilter_ipv4/ipt_addrtype.h'] = (['sys/types.h'],
                                                  OK, 'u_int16_t')

    exc['linux/netfilter_ipv4/ipt_ah.h'] = (['sys/types.h'],
                                            OK, 'u_int32_t')

    exc['linux/netfilter_ipv4/ipt_ecn.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv4/ipt_ttl.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv6.h'] = (['limits.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                     OK, 'INT_MIN in_addr in6_addr')

    exc['linux/netfilter_ipv6/ip6_tables.h'] = (['limits.h', 'sys/types.h', SOCKADDR, 'linux/if.h', SA_FAMILY_T, 'linux/in.h', 'linux/in6.h'],
                                                OK, 'INT_MIN in_addr in6_addr  u_int16_t u_int8_t IFNAMSIZ')

    exc['linux/netfilter_ipv6/ip6t_HL.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv6/ip6t_REJECT.h'] = (['sys/types.h'],
                                                 OK, 'u_int32_t')

    exc['linux/netfilter_ipv6/ip6t_ah.h'] = (['sys/types.h'],
                                             OK, 'u_int32_t')

    exc['linux/netfilter_ipv6/ip6t_frag.h'] = (['sys/types.h'],
                                               OK, 'u_int32_t')

    exc['linux/netfilter_ipv6/ip6t_hl.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv6/ip6t_ipv6header.h'] = (['sys/types.h'],
                                                     OK, 'u_int8_t')

    exc['linux/netfilter_ipv6/ip6t_mh.h'] = (['sys/types.h'],
                                             OK, 'u_int8_t')

    exc['linux/netfilter_ipv6/ip6t_opts.h'] = (['sys/types.h'],
                                               OK, 'u_int32_t')

    exc['linux/netfilter_ipv6/ip6t_rt.h'] = (['sys/types.h', 'linux/in6.h'],
                                             OK, 'u_int32_t in6_addr')

    exc['linux/netlink.h'] = ([SA_FAMILY_T],
                              OK, 'sa_family_t')

    exc['linux/netrom.h'] = ([SA_FAMILY_T, 'linux/ax25.h'],
                             OK, 'ax25_address')

    exc['linux/nfs_mount.h'] = ([SA_FAMILY_T],
                                OK, 'sa_family_t')

    exc['linux/nfsd/syscall.h'] = ([SOCKADDR, SA_FAMILY_T, 'linux/in.h', 'linux/nfs.h', 'linux/nfsd/nfsfh.h'],
                                   OK, 'in_addr NFS_MAXPATHLEN sockaddr NFS_FHSIZE struct cr_getfs')

    exc['linux/patchkey.h'] = ([SIZE_T],
                               WARN | BLACKLIST, 'error: #error "patchkey.h included directly"')

    exc['linux/phonet.h'] = ([SA_FAMILY_T, SOCKADDR],
                             OK, 'sa_family_t sockaddr')

    exc['linux/quota.h'] = (['sys/types.h', '* #define _LINUX_TIME_H', 'linux/coda.h'],
                            OK | WARN, 'caddr_t, coda.h includes linux/time.h which conflicts with sys/types.h')

    exc['linux/reiserfs_xattr.h'] = ([SIZE_T],
                                     OK, 'size_t')

    exc['linux/romfs_fs.h'] = (['linux/types.h'],
                               OK, '__be32')

    exc['linux/rose.h'] = ([SA_FAMILY_T, 'linux/ax25.h'],
                           OK, 'sa_family_t')

    exc['linux/route.h'] = ([SOCKADDR],
                            OK, 'sockaddr')

    exc['linux/rtnetlink.h'] = ([SA_FAMILY_T],
                                OK, 'sa_family_t')

    exc['linux/scc.h'] = (['linux/sockios.h'],
                          OK, 'SIOCDEVPRIVATE')

    exc['linux/signal.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/signalfd.h'] = ([PID_T],
                               OK, 'pid_t')

    exc['linux/sysctl.h'] = ([SIZE_T],
                             OK, 'size_t')

    exc['linux/un.h'] = ([SA_FAMILY_T],
                         OK, 'sa_family_t')

    exc['linux/usb/vstusb.h'] = ([SIZE_T],
                                 OK, 'size_t')

    exc['linux/virtio_balloon.h'] = (['linux/types.h', '* typedef __u16 u16;', '* typedef __u64 u64;'],
                                     OK | WARN, 'u16 u64 not defined')

    exc['linux/wireless.h'] = ([SOCKADDR],
                               OK, 'sockaddr')

    exc['linux/x25.h'] = ([SA_FAMILY_T],
                          OK, 'sa_family_t')

    exc['sound/asequencer.h'] = ([SIZE_T, 'linux/time.h', 'sound/asound.h'],
                                 OK, '__bitwise  snd_timer_id size_t timespec')

    exc['sound/asound.h'] = ([SIZE_T, 'linux/time.h'],
                             OK, 'size_t snd_timer_id size_t timespec')

    exc['sound/emu10k1.h'] = ([SIZE_T, 'linux/time.h', 'sound/asound.h', '* #define DECLARE_BITMAP(name,bits) unsigned long name[bits/8];'],
                              OK | WARN, 'snd_ctl_elem_id DECLARE_BITMAPS - missing')

    exc['sound/sfnt_info.h'] = ([SIZE_T, 'linux/time.h'],
                                OK, 'size_t timespec')

    #exc[''] = ([''], OK, '')
