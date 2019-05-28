from argparse import ArgumentParser
from pktgen import PacketGen

def main():
	##############################
	# parse parameters
	##############################
	parser = ArgumentParser()
	parser.add_argument("packet", action="store")
	parser.add_argument("topo", action="store")
	group = parser.add_mutually_exclusive_group()
	group.add_argument("--payload", dest="payload",	action="store")
	group.add_argument("--payload-len", dest="payload_len",	action="store")
	parser.add_argument("--fragment", dest="fragment", action="store_true")
	optslist = ['--src-mac', '--dst-mac']
	optslist.extend(['--vlan-id', '--vlan-priority'])
	optslist.extend(['--llc-ssap', '--llc-dsap', '--llc-ctrl'])
	optslist.extend(['--arp-op', '--arp-hwsrc', '--arp-hwdst', '--arp-psrc', '--arp-pdst'])
	optslist.extend(['--src-ip', '--dst-ip', '--tos', '--ttl', '--frag', '--tc', '--hl'])
	optslist.extend(['--exthdrs', '--rt-len', '--rt-type', '--rt-segleft', '--rt-addresses', '--frag-offset', '--frag-m', '--frag-id'])
	optslist.extend(['--src-port', '--dst-port', '--tcp-dataofs', '--tcp-flags'])
	optslist.extend(['--icmp-type', '--icmp-code', '--icmp6-type', '--icmp6-code'])
	optslist.extend(['--sctp-types', '--sctp-data'])
	tcpoptsmap = {	'--opt-mss':		('MSS', int),
			'--opt-wscale':		('WScale', int),
			'--opt-timestamp':	('Timestamp', str),
			'--opt-altchksum':	('AltChkSum', str),
			'--opt-altchksumopt':	('AltChkSumOpt', str),
			'--opt-sack':		('SAck', str),
			'--opt-sackok':		('SAckOK', str),
			'--opt-mood':		('Mood', str) }
	for option in optslist:
		optionname = option.replace('--','').replace('-','_')
		if option == '--exthdrs' or option == '--rt-addresses' or option == '--sctp-types':
			parser.add_argument(option, dest=optionname, action="append")
		else:
			parser.add_argument(option, dest=optionname, action="store")
	for option in tcpoptsmap.keys():
		optionname = option.replace('--','').replace('-','_')
		optiontype = tcpoptsmap[option][1]
		if optiontype == int:
			parser.add_argument(option, dest=optionname, action="store")
		else:
			parser.add_argument(option, dest=optionname, action="store", nargs="?", const="NullString")
	args = parser.parse_args()
	##############################
	# generate the packet
	##############################
	pktgen = PacketGen(args.packet,args.topo)
	optslist.extend(['--payload', '--payload-len', '--fragment'])
	for option in optslist:
		optionname = option.replace('--','').replace('-','_')
		if hasattr(args, optionname) and getattr(args, optionname):
			if option == '--sctp-types':
				pktgen.set_field_value('--sctp-chunks', getattr(args, optionname))
			else:
				pktgen.set_field_value(option, getattr(args, optionname))
	tcpoptions = []
	for option in tcpoptsmap.keys():
		optionname = option.replace('--','').replace('-','_')
		optionkey = tcpoptsmap[option][0]
		optiontype = tcpoptsmap[option][1]
		if hasattr(args, optionname) and getattr(args, optionname):
			optionvalue = optiontype(getattr(args, optionname))
			if getattr(args, optionname) == 'NullString':
				tcpoptions.append((optionkey, ''))
			else:
				tcpoptions.append((optionkey, optionvalue))
	if len(tcpoptions) > 0:
		pktgen.set_field_value('--tcp-options', tcpoptions)
	##############################
	# send the packet
	##############################
	pktgen.send()

if __name__ == "__main__":  
	main()

