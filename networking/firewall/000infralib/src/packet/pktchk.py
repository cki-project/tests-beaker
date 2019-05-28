import socket, struct
from scapy.all import *
from netfilterqueue import NetfilterQueue

class PacketChk(object):
	__l2list = ('ether', '8021q', '8023sap', '8023snap')
	__l3list = ('arp', 'ip', 'ipv6')
	__l4list = ('tcp', 'udp', 'sctp', 'icmp', 'icmpv6', 'ah', 'ahv6', 'esp', 'espv6')
	__l2map = {	'ether':	('Ether',),
			'8021q':	('Ether',),
			'8023sap':	('Dot3', 'LLC'),
			'8023snap':	('Dot3', 'LLC', 'SNAP') }
	__l3map = {	'arp':	'ARP',
			'ip':	'IP',
			'ipv6':	'IPv6' }
	__l4map = {	'tcp':		'TCP',
			'udp':		'UDP',
			'sctp':		'SCTP',
			'icmp':		'ICMP',
			'icmpv6':	None }
	__skmap = {	'arp':	socket.AF_INET,
			'ip':	socket.AF_INET,
			'ipv6':	socket.AF_INET6 }

	def __init__(self,pkttype):
		l2proto = None; l3proto = None; l4proto = None
		for key in pkttype.split("-"):
			if key in PacketChk.__l2list: l2proto = key
			if key in PacketChk.__l3list: l3proto = key
			if key in PacketChk.__l4list: l4proto = key
		self.l2class = (); self.l3class = None; self.l4class = None
		if l2proto: self.l2class = PacketChk.__l2map.get(l2proto)
		if l3proto: self.l3class = PacketChk.__l3map.get(l3proto)
		if l4proto: self.l4class = PacketChk.__l4map.get(l4proto)
		self.sktype = socket.AF_INET
		if l3proto: self.sktype = PacketChk.__skmap.get(l3proto)

	##############################
	# get packet info by nfqueue
	##############################
	def get_nfqueues(self,nfq_num,pkt_num,accept):
		############################################################
		# https://bugzilla.redhat.com/show_bug.cgi?id=1304959
		############################################################
		self.nfqueue = NetfilterQueue(af=self.sktype)
		self.accept = accept
		self.nfqueue.bind(int(nfq_num), self.callback_nfqueue, int(pkt_num))

	def get_nfqueue(self):
		self.nfqueue.run()
		# unbind() will cause segment fault on rhel7, need debugging
		# self.nfqueue.unbind()

	def callback_nfqueue(self,pkt):
		self.packet = getattr(sys.modules[__name__], self.l3class)(_pkt=pkt.get_payload())
		# It seems that scapy can not parse IPv6-SCTP packet normally,
		# so specify SCTP class manually.
		if self.l3class == 'IPv6' and self.packet[IPv6].nh == 132:
			content = pkt.get_payload()
			ipv6_content = content[0:40]
			sctp_content = content[40:]
			self.packet = IPv6(_pkt=ipv6_content)/SCTP(_pkt=sctp_content)
		self.packet.show()
		if self.accept == True:
			pkt.accept()
		else:
			pkt.drop()

	##############################
	# match packet type
	##############################
	def match_pkttype(self):
		for l2class in self.l2class:
			if not getattr(sys.modules[__name__], l2class) in self.packet:
				raise Exception("l2proto is not matched!")
		if self.l3class:
			if not getattr(sys.modules[__name__], self.l3class) in self.packet:
				raise Exception("l3proto is not matched!")
		if self.l4class:
			if not getattr(sys.modules[__name__], self.l4class) in self.packet:
				raise Exception("l4proto is not matched!")

	##############################
	# match specified fielf for the packet
	##############################
	__pktmap = {	'--indev':		( None,		'indev' ),
			'--outdev':		( None,		'outdev' ),
			'--physindev':		( None,		'physindev' ),
			'--physoutdev':		( None,		'physoutdev' ),
			'--src-mac':		( 'Ether',	'src' ),
			'--dst-mac':		( 'Ether',	'dst' ),
			'--arp-op':		( 'ARP',	'op' ),
			'--arp-ptype':		( 'ARP',	'ptype' ),
			'--arp-hwtype':		( 'ARP',	'hwtype' ),
			'--arp-plen':		( 'ARP',	'plen' ),
			'--arp-hwlen':		( 'ARP',	'hwlen' ),
			'--arp-psrc':		( 'ARP',	'psrc' ),
			'--arp-pdst':		( 'ARP',	'pdst' ),
			'--arp-hwsrc':		( 'ARP',	'hwsrc' ),
			'--arp-hwdst':		( 'ARP',	'hwdst' ),
			'--src-ip':		( 'IP|IPv6',	'src' ),
			'--dst-ip':		( 'IP|IPv6',	'dst' ),
			'--tos':		( 'IP',		'tos' ),
			'--ttl':		( 'IP',		'ttl' ),
			'--proto':		( 'IP',		'proto' ),
			'--flag':		( 'IP',		'flags' ),
			'--flags':		( 'IP',		'flags' ),
			'--hl':			( 'IPv6',	'hlim' ),
			'--nh':			( 'IPv6',	'nh' ),
			'--src-port':		( 'TCP|UDP',	'sport' ),
			'--dst-port':		( 'TCP|UDP',	'dport' ),
			'--tcp-flag':		( 'TCP',	'flags' ),
			'--tcp-flags':		( 'TCP',	'flags' ),
			'--tcp-option':		( 'TCP',	'options' ),
			'--tcp-options':	( 'TCP',	'options' ),
			'--icmp-type':		( 'ICMP',	'type' ),
			'--icmp-code':		( 'ICMP',	'code' ),
			'--icmp6-type':		( 'IPv6',	'type' ),
			'--icmp6-code':		( 'IPv6',	'code' ),
			'--payload':		( 'Raw',	'load' ),
			'--payload-len':	( 'Raw',	'load' ) }

	__ipflags_bitmap = FlagsField("flags", 0x0, 3, ["MF","DF","evil"])
	__tcpflags_bitmap = FlagsField("flags",	0x2, 8, "FSRPAUEC")

	def match_packet(self,key,value):
		# get classname and fieldname
		classname = PacketChk.__pktmap[key][0]
		fieldname = PacketChk.__pktmap[key][1]
		if classname == 'IP|IPv6':
			classname = self.l3class
		if classname == 'TCP|UDP':
			classname = self.l4class
		# get title and pktvalue
		if classname == None:
			title = fieldname
			pktvalue = getattr(self.packet, fieldname)
		else:
			title = '[%s].%s' % (classname, fieldname)
			pktvalue = getattr(self.packet[getattr(sys.modules[__name__], classname)], fieldname)
		# do the value match
		if key == '--flag':
			expvalue = PacketChk.__ipflags_bitmap.any2i(None, value)
			if expvalue | pktvalue == pktvalue:
				return 0
			pktvalue = PacketChk.__ipflags_bitmap.i2repr(None, pktvalue)
		elif key == '--flags':
			expvalue = PacketChk.__ipflags_bitmap.any2i(None, value)
			if expvalue == pktvalue:
				return 0
			pktvalue = PacketChk.__ipflags_bitmap.i2repr(None, pktvalue)
		elif key == '--tcp-flag':
			expvalue = PacketChk.__tcpflags_bitmap.any2i(None, value)
			if expvalue | pktvalue == pktvalue:
				return 0
			pktvalue = PacketChk.__tcpflags_bitmap.i2repr(None, pktvalue)
		elif key == '--tcp-flags':
			expvalue = PacketChk.__tcpflags_bitmap.any2i(None, value)
			if expvalue == pktvalue:
				return 0
			pktvalue = PacketChk.__tcpflags_bitmap.i2repr(None, pktvalue)
		elif key == '--tcp-option':
			if type(value) == str:
				for option in pktvalue:
					if value == option[0]:
						return 0
			if type(value) == tuple:
				for option in pktvalue:
					if value[0] == option[0]:
						if type(option[1])(value[1]) == option[1]:
							return 0
		elif key == '--payload-len':
			if len(pktvalue) == int(value):
				return 0
			pktvalue = len(pktvalue)
		elif value.count("-") != 0:
			values = value.split("-")
			if type(pktvalue)(values[0]) <= pktvalue <= type(pktvalue)(values[1]):
				return 0
		else:
			if value.startswith('0x'):
				value = int(value, 16)
			if pktvalue == type(pktvalue)(value):
				return 0
		raise Exception("%s: expected_value=%s, actual_value=%s, not matched!" % (title, value, pktvalue))

