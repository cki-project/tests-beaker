#!/usr/bin/env python

import sys
from optparse import OptionParser
from scapy.all import *


def main():
	if len(sys.argv) == 1:
		parser.error("incorrect number of arguments")
		sys.exit(1)

	parser = OptionParser(usage="usage: %prog -m -i [-t][-l][-p][-s][-o][-r]\n\nExample: %prog -t 60 -l 64 -p 3000:: -m 00:11:22:33:44:55 -i veth0 -r \"3001:: 3002::\" -s \"60 120\" -o \"64 65\"")
	parser.add_option("-t", "--lifetime", dest="lft", default="1800", help="router lifetime, default is 1800")
	parser.add_option("-l", "--preflength", dest="prefl", default="64", help="prefix length in prefix info, default is 64")
	parser.add_option("-p", "--prefix", dest="pref", default="2000::", help="prefix in prefix info, default is 2000::")
	parser.add_option("-s", "--secrt", dest="secrt",  help="seconds of route lifetime in route info")
	parser.add_option("-o", "--preflenrt", dest="preflenrt", help="prefix len in route info")
	parser.add_option("-r", "--prefrt", dest="prefrt", help="prefix in route info")
	parser.add_option("-m", "--src_mac", dest="src_mac", help="Source mac address")
	parser.add_option("-i", "--interface", dest="iface", help="interface to send")
	parser.add_option("-a", "--srcaddr", dest="saddr", help="source addr")

	(opt, args) = parser.parse_args()

	ipv6 = IPv6(dst = "ff02::1")
	if (opt.saddr != None ):
		ipv6.src=opt.saddr
	ra = ICMPv6ND_RA(routerlifetime = int(opt.lft))
	lladdr = ICMPv6NDOptSrcLLAddr(lladdr = opt.src_mac)
	pre = ICMPv6NDOptPrefixInfo(prefixlen = int(opt.prefl), validlifetime = 0x80, \
			preferredlifetime = 0x80, prefix = opt.pref)
	packet=Ether()/ipv6/ra/lladdr/pre
	if (opt.prefrt != None):
		prefixrts=opt.prefrt.split(" ")
		secrts=list()
		preflenrts=list()
		if (opt.secrt != None):
			secrts=opt.secrt.split(" ")
		if (len(secrts) < len(prefixrts)):
			i=len(secrts)
			while(i < len(prefixrts)):
				secrts.append(0xffffffff)
				i += 1
		if (opt.preflenrt != None):
			preflenrts=opt.preflenrt.split(" ")
		if (len(preflenrts) < len(prefixrts)):
			i=len(preflenrts)
			while(i < len(prefixrts)):
				preflenrts.append(64)
				i += 1
		i=0
		while(i < len(prefixrts)):
			rtinfo=ICMPv6NDOptRouteInfo(plen=int(preflenrts[i]), rtlifetime=int(secrts[i]), prefix=prefixrts[i])
			packet=packet/rtinfo
			i += 1

	#packet.display()
	sendp(packet, iface=opt.iface)



if __name__ == '__main__':
	main()
