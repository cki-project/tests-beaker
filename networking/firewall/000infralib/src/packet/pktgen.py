from scapy.all import *

class PacketGen(object):
	############################################################
	# Ethernet II (DEC,Intel,Xerox)
	#  | srcmac (6bytes) | dstmac (6bytes) | type (2bytes) | data (46~1500bytes) | FCS (4bytes) |
	# IEEE 802.3 raw (Novell)
	#  | srcmac (6bytes) | dstmac (6bytes) | len (2bytes) | 0xFFFF (2bytes) | data (44~1498bytes) | FCS (4bytes) |
	# IEEE 802.3 SAP (to make "Ethernet II" and "Novell 802.3 raw" compatible)
	#  | srcmac (6bytes) | dstmac (6bytes) | len (2bytes) | DSAP (1byte) | SSAP(1byte) | Ctrl (1byte) | data (43~1497bytes) | FCS (4bytes) |
	# IEEE 802.3 SNAP
	#  | srcmac (6bytes) | dstmac (6bytes) | len (2bytes) | 0xAA (1byte) | 0xAA(1byte) | 0x03 (1byte) | OUIID (3bytes) | type (2bytes) | data (38~1492bytes) | FCS (4bytes) |
	############################################################
	__classmap = {	'ether':	('Ether',),
			'8021q':	('Ether', 'Dot1Q'),
			'8023sap':	('Dot3', 'LLC'),
			'8023snap':	('Dot3', 'LLC', 'SNAP'),
			'arp':		('ARP',),
			'ip':		('IP',),
			'ipv6':		('IPv6',),
			'tcp':		('TCP',),
			'udp':		('UDP',),
			'sctp':		('SCTP', 'SCTPChunkInit'),
			'icmp':		('ICMP',),
			'icmpv6':	('ICMPv6EchoRequest',) }

	__fieldmap = {	'--src-mac':		( ('Ether','Dot3'),		'src',		None,	str ),
			'--dst-mac':		( ('Ether','Dot3'),		'dst',		None,	str ),
			'--vlan-id':		( ('Dot1Q',),			'vlan',		0,	int ),
			'--vlan-priority':	( ('Dot1Q',),			'prio',		None,	int ),
			'--llc-dsap':		( ('LLC',),			'dsap',		0xaa,	int ),
			'--llc-ssap':		( ('LLC',),			'ssap',		0xaa,	int ),
			'--llc-ctrl':		( ('LLC',),			'ctrl',		3,	int ),
			'--arp-op':		( ('ARP',),			'op',		None,	int ),
			'--arp-hwsrc':		( ('ARP',),			'hwsrc',	None,	str ),
			'--arp-hwdst':		( ('ARP',),			'hwdst',	None,	str ),
			'--arp-psrc':		( ('ARP',),			'psrc',		None,	str ),
			'--arp-pdst':		( ('ARP',),			'pdst',		None,	str ),
			'--src-ip':		( ('IP','IPv6'),		'src',		None,	str ),
			'--dst-ip':		( ('IP','IPv6'),		'dst',		None,	str ),
			'--tos':		( ('IP',),			'tos',		None,	int ),
			'--ttl':		( ('IP',),			'ttl',		None,	int ),
			'--frag':		( ('IP',),			'frag',		None,	int ),
			'--tc':			( ('IPv6',),			'tc',		None,	int ),
			'--hl':			( ('IPv6',),			'hlim',		None,	int ),
			'--exthdrs':		( (),				'',		[],	list ),
			'--rt-len':		( ('IPv6ExtHdrRouting',),	'len',		None,	int ),
			'--rt-len':		( ('IPv6ExtHdrRouting',),	'len',		None,	int ),
			'--rt-type':		( ('IPv6ExtHdrRouting',),	'type',		None,	int ),
			'--rt-segleft':		( ('IPv6ExtHdrRouting',),	'segleft',	None,	int ),
			'--rt-addresses':	( ('IPv6ExtHdrRouting',),	'addresses',	None,	list ),
			'--frag-offset':	( ('IPv6ExtHdrFragment',),	'offset',	None,	int ),
			'--frag-m':		( ('IPv6ExtHdrFragment',),	'm',		None,	int ),
			'--frag-id':		( ('IPv6ExtHdrFragment',),	'id',		None,	int ),
			'--src-port':		( ('TCP','UDP','SCTP'),		'sport',	32768,	int ),
			'--dst-port':		( ('TCP','UDP','SCTP'),		'dport',	80,	int ),
			'--tcp-dataofs':	( ('TCP',),			'dataofs',	None,	int ),
			'--tcp-flags':		( ('TCP',),			'flags',	None,	str ),
			'--tcp-options':	( ('TCP',),			'options',	None,	list ),
			'--icmp-type':		( ('ICMP',),			'type',		None,	int ),
			'--icmp-code':		( ('ICMP',),			'code',		None,	int ),
			'--icmp6-type':		( (),				'',		None,	int ),
			'--icmp6-code':		( (),				'',		None,	int ),
			'--sctp-chunks':	( (),				'',		[],	list ),
			'--sctp-data':		( ('SCTPChunkData',),		'data',		None,	str ),
			'--payload':		( None,				'',		'',	str ),
			'--payload-len':	( None,				'',		0,	int ),
			'--fragment':		( None,				'',		False,	bool ),
			'--iface':		( None,				'',		None,	str ) }

	__topomap = {	'cb':	('cb_client_if1', 'cb_client_mac1', 'cb_bridge_mac0', 'cb_client_ip1', 'cb_bridge_ip0'),
			'cs':	('cs_client_if1', 'cs_client_mac1', 'cs_server_mac1', 'cs_client_ip1', 'cs_server_ip1'),
			'bf':	('bf_client_if1', 'bf_client_mac1', 'bf_server_mac1', 'bf_client_ip1', 'bf_server_ip1'),
			'rf':	('rf_client_if1', 'rf_client_mac1', 'rf_router_mac1', 'rf_client_ip1', 'rf_server_ip1') }
	__topotitlemap = {	0:	( ( None,	'iface'), ),
				1:	( ('Ether',	'src'), ('Dot3',	'src') ),
				2:	( ('Ether',	'dst'), ('Dot3',	'dst') ),
				3:	( ('IP',	'src'),	('IPv6',	'src'), ('ARP',	'psrc') ),
				4:	( ('IP',	'dst'),	('IPv6',	'dst'), ('ARP',	'pdst') ) }

	def __init__(self,pkttype,topotype):
		for splittype in pkttype.split("-"):
			if not splittype in PacketGen.__classmap.keys():
				raise Exception("packet type is unsupported!")
			for classname in PacketGen.__classmap[splittype]:
				setattr(self, classname.lower(), getattr(sys.modules[__name__], classname)())
		for optionname in PacketGen.__fieldmap.keys():
			classesname = PacketGen.__fieldmap[optionname][0]
			fieldname = PacketGen.__fieldmap[optionname][1]
			defaultvalue = PacketGen.__fieldmap[optionname][2]
			if type(classesname) == tuple:
				for classname in classesname:
					if hasattr(self, classname.lower()):
						if defaultvalue:
							setattr(getattr(self, classname.lower()), fieldname, defaultvalue)
			else:
				setattr(self, optionname.replace('--','').replace('-',''), defaultvalue)
		if not topotype in PacketGen.__topomap.keys():
			raise Exception("topo type is unsupported!")
		for index in PacketGen.__topotitlemap.keys():
			defaultvalue = os.environ.get(PacketGen.__topomap[topotype][index])
			objecttuple = PacketGen.__topotitlemap[index]
			finishedflag = False
			for obj in objecttuple:
				if obj[0]:
					if hasattr(self, obj[0].lower()):
						setattr(getattr(self, obj[0].lower()), obj[1], defaultvalue)
						finishedflag = True
				else:
					setattr(self, obj[1], defaultvalue)
					finishedflag = True
			if not finishedflag:
				obj = objecttuple[0]
				setattr(self, obj[0].lower(), getattr(sys.modules[__name__], obj[0])())
				setattr(getattr(self, obj[0].lower()), obj[1], defaultvalue)

	__ipv6nhcls = {	'hop':		"IPv6ExtHdrHopByHop",
			'dst':		"IPv6ExtHdrDestOpt",
			'route':	"IPv6ExtHdrRouting",
			'frag':		"IPv6ExtHdrFragment" }

	__sctpchunktypescls = {	0 :	"SCTPChunkData",
				1 :	"SCTPChunkInit",
				2 :	"SCTPChunkInitAck",
				3 :	"SCTPChunkSACK",
				4 :	"SCTPChunkHeartbeatReq",
				5 :	"SCTPChunkHeartbeatAck",
				6 :	"SCTPChunkAbort",
				7 :	"SCTPChunkShutdown",
				8 :	"SCTPChunkShutdownAck",
				9 :	"SCTPChunkError",
				10 :	"SCTPChunkCookieEcho",
				11 :	"SCTPChunkCookieAck",
				14 :	"SCTPChunkShutdownComplete", }

	__icmp6typescls = {	1:	"ICMPv6DestUnreach",
				2:	"ICMPv6PacketTooBig",
				3:	"ICMPv6TimeExceeded",
				4:	"ICMPv6ParamProblem",
				128:	"ICMPv6EchoRequest",
				129:	"ICMPv6EchoReply",
				130:	"ICMPv6MLQuery",
				131:	"ICMPv6MLReport",
				132:	"ICMPv6MLDone",
				133:	"ICMPv6ND_RS",
				134:	"ICMPv6ND_RA",
				135:	"ICMPv6ND_NS",
				136:	"ICMPv6ND_NA",
				137:	"ICMPv6ND_Redirect",
				139:	"ICMPv6NIQuery",
				140:	"ICMPv6NIReply",
				141:	"ICMPv6ND_INDSol",
				142:	"ICMPv6ND_INDAdv",
				144:	"ICMPv6HAADRequest",
				145:	"ICMPv6HAADReply",
				146:	"ICMPv6MPSol",
				147:	"ICMPv6MPAdv",
				151:	"ICMPv6MRD_Advertisement",
				152:	"ICMPv6MRD_Solicitation",
				153:	"ICMPv6MRD_Termination", }

	def set_field_value(self,key,value):
		if not key in PacketGen.__fieldmap.keys():
			raise Exception("option type is unsupported!")
		classesname = PacketGen.__fieldmap[key][0]
		fieldname = PacketGen.__fieldmap[key][1]
		fieldvalue = PacketGen.__fieldmap[key][3](value)
		if type(classesname) != tuple:
			setattr(self, key.replace('--','').replace('-',''), fieldvalue)
			return
		if len(classesname) != 0:
			finishedflag = False
			for classname in classesname:
				if hasattr(self, classname.lower()):
					setattr(getattr(self, classname.lower()), fieldname, fieldvalue)
					finishedflag = True
			if not finishedflag:
				raise Exception("No suitable class existed for %s setting!" % key)
			return
		if key == '--exthdrs':
			for exthdr in fieldvalue:
				classname = PacketGen.__ipv6nhcls[exthdr]
				setattr(self, classname.lower(), getattr(sys.modules[__name__], classname)())
				for value in PacketGen.__fieldmap.values():
					if not value[0]:
						continue
					if classname in value[0]:
						if value[2]:
							setattr(getattr(self, classesname.lower()), value[1], value[2])
		if key == '--sctp-chunks':
			if hasattr(self, 'SCTPChunkInit'.lower()):
				delattr(self, 'SCTPChunkInit'.lower())
			for sctpchunk in fieldvalue:
				classname = PacketGen.__sctpchunktypescls[int(sctpchunk)]
				setattr(self, classname.lower(), getattr(sys.modules[__name__], classname)())
				for value in PacketGen.__fieldmap.values():
					if not value[0]:
						continue
					if classname in value[0]:
						if value[2]:
							setattr(getattr(self, classesname.lower()), value[1], value[2])
		if key == '--icmp6-type':
			if hasattr(self, 'ICMPv6EchoRequest'.lower()):
				delattr(self, 'ICMPv6EchoRequest'.lower())
			classname = PacketGen.__icmp6typescls[fieldvalue]
			setattr(self, classname.lower(), getattr(sys.modules[__name__], classname)())
		if key == '--icmp6-code':
			finishedflag = False
			for code in (1, 2, 3, 4, 128):
				classname = PacketGen.__icmp6typescls[code]
				if hasattr(self, classname.lower()):
					setattr(getattr(self, classname.lower()), 'code', fieldvalue)
					finishedflag = True
			if not finishedflag:
				raise Exception("No ICMPv6 class existed for --icmp6-code setting!")

	__pktlist = ['Ether', 'Dot1Q', 'Dot3', 'LLC', 'SNAP', 'ARP', 'IP', 'IPv6']
	__pktlist.extend(__ipv6nhcls.values())
	__pktlist.extend(['TCP', 'UDP','SCTP'])
	__pktlist.extend(__sctpchunktypescls.values())
	__pktlist.extend(['ICMP'])
	__pktlist.extend(__icmp6typescls.values())

	def send(self):
		if getattr(self, 'fragment') == True:
			if hasattr(self, 'ipv6'):
				setattr(self, 'IPv6ExtHdrFragment'.lower(), IPv6ExtHdrFragment())
		# it seems it bug in scapy, IPv6 nh field could not be setted automaticlly
		# fix start
		if hasattr(self, 'sctp'):
			index = PacketGen.__pktlist.index('SCTP')
			while (index > 0):
				index = index -1
				if not hasattr(self, PacketGen.__pktlist[index].lower()):
					continue
				if not hasattr(getattr(self, PacketGen.__pktlist[index].lower()), 'nh'):
					break
				setattr(getattr(self, PacketGen.__pktlist[index].lower()), 'nh', 132)
				break
		# fix stop
		packet = None
		for classname in PacketGen.__pktlist:
			if hasattr(self, classname.lower()):
				if packet:
					packet = packet/getattr(self, classname.lower())
				else:
					packet = getattr(self, classname.lower())
		if len(getattr(self, 'payload')) != 0:
			packet = packet/getattr(self, 'payload')
		elif getattr(self, 'payloadlen') != 0:
			packet = packet/("X"*getattr(self, 'payloadlen'))
		else:
			packet = packet
		if getattr(self, 'fragment') == False:
			sendp(packet, iface=getattr(self, 'iface'))
		else:
			if hasattr(self, 'ip'):
				sendp(fragment(packet), iface=getattr(self, 'iface'))
			if hasattr(self, 'ipv6'):
				sendp(fragment6(packet, 1296), iface=getattr(self, 'iface'))

