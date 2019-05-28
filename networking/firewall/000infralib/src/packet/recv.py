import sys, traceback
from argparse import ArgumentParser
from pktchk import PacketChk

def nfqueue(args):
	try:
		if args.nfq_num:
			nfq_num = int(args.nfq_num)
		else:
			nfq_num = 1
		if args.frags_num:
			pkt_num = int(args.frags_num)
		else:
			pkt_num = 1
		pktchk = PacketChk(args.packet)
		pktchk.get_nfqueues(nfq_num, pkt_num, args.nfq_accept)
		##############################
		# match the first packet
		##############################
		pktchk.get_nfqueue()
		pktchk.match_pkttype()
		match_packet(pktchk,args,'nfqueue')
		##############################
		# match the following packets
		##############################
		for loop in range(2,pkt_num+1):
			pktchk.get_nfqueue()
			# match_packet(pktchk,args,'ipip6')
	except:
		traceback.print_exc(file=sys.stdout)
		sys.exit(1)
	else:
		sys.exit(0)

subcmdsmap = {	'nfqueue':	('ipip6', 'tcpudp', 'icmpicmp6', 'others') }

argsmap = {	'iodev':	('--indev', '--outdev'),
		'physiodev':	('--physindev', '--physoutdev'),
		'ether':	('--src-mac', '--dst-mac'),
		'arp':		('--arp-op', '--arp-ptype', '--arp-hwtype', '--arp-plen', '--arp-hwlen', '--arp-psrc', '--arp-pdst', '--arp-hwsrc', '--arp-hwdst'),
		'ipip6':	('--src-ip', '--dst-ip', '--tos', '--ttl', '--flags', '--proto', '--hl', '--nh'),
		'tcpudp':	('--src-port', '--dst-port', '--tcp-flag', '--tcp-flags'),
		'icmpicmp6':	('--icmp-type', '--icmp-code', '--icmp6-type', '--icmp6-code'),
		'others':	('--payload', '--payload-len') }

argsoptmap = {	'--opt-mss':		'MSS',
		'--opt-wscale':		'WScale',
		'--opt-timestamp':	'Timestamp',
		'--opt-altchksum':	'AltChkSum',
		'--opt-altchksumopt':	'AltChkSumOpt',
		'--opt-sack':		'SAck',
		'--opt-sackok':		'SAckOK',
		'--opt-mood':		'Mood' }

def match_packet(pktchk,args,subcmd):
	argspktlist = []
	for pkttype in subcmdsmap[subcmd]:
		argspktlist.extend(argsmap[pkttype])
	for option in argspktlist:
		optionname = option.replace('--','').replace('-','_')
		if hasattr(args, optionname) and getattr(args, optionname):
			pktchk.match_packet(option, getattr(args, optionname)[0])
	if not 'tcpudp' in subcmdsmap[subcmd]:
		return 0
	for option in argsoptmap.keys():
		optionname = option.replace('--','').replace('-','_')
		if hasattr(args, optionname) and getattr(args, optionname):
			if getattr(args, optionname) == "has_key":
				pktchk.match_packet('--tcp-option', argsoptmap[option])
			else:
				pktchk.match_packet('--tcp-option', (argsoptmap[option], getattr(args, optionname)))

def add_arguments(parser, subcmd):
	argslist = []
	for pkttype in subcmdsmap[subcmd]:
			argslist.extend(argsmap[pkttype])
	for option in argslist:
		optionname = option.replace('--','').replace('-','_')
		parser.add_argument(option, dest=optionname, nargs='+', action='store')
	if not 'tcpudp' in subcmdsmap[subcmd]:
		return 0
	for option in argsoptmap.keys():
		optionname = option.replace('--','').replace('-','_')
		parser.add_argument(option, dest=optionname, nargs="?", action='store', const='has_key')

def main():
	##############################
	# parse parameters
	##############################
	parser = ArgumentParser()
	subparsers = parser.add_subparsers()
	for key in subcmdsmap.keys():
		subparser = subparsers.add_parser(key)
		subparser.set_defaults(func=eval(key.replace('-','_')))
		subparser.add_argument("packet", action="store", help="type of received packet")
		if key == 'nfqueue':
			# optional arguments (fragment settings)
			subparser.add_argument("--frags-num", dest="frags_num", action="store")
			# optional arguments (nfqueue settings)
			subparser.add_argument("-n", "--nfq-num", dest="nfq_num", action="store")
			subparser.add_argument("--nfq-accept", dest="nfq_accept", action="store_true")
		add_arguments(subparser, key)
	##############################
	# analyse and match the packet
	##############################
	args = parser.parse_args()
	args.func(args)

if __name__ == "__main__":  
	main()

