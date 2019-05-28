import struct, socket
from argparse import ArgumentParser

def client(args):
	if args.family == "AF_INET":
		family = socket.AF_INET
	elif args.family == "AF_INET6":
		family = socket.AF_INET6

	if args.type == "SOCK_STREAM":
		type = socket.SOCK_STREAM
	elif args.type == "SOCK_DGRAM":
		type = socket.SOCK_DGRAM

	s = socket.socket(family, type)
	s.settimeout(int(args.timeout))
	try:
		s.connect((args.peerip, int(args.peerport)))
	except:
		s.close()

def server(args):
	if args.family == "AF_INET":
		family = socket.AF_INET
		level = 0 # /usr/include/bits/in.h
		optname = 19 # /usr/include/linux/in.h
	elif args.family == "AF_INET6":
		family = socket.AF_INET6
		level = 41 # /usr/include/bits/in.h
		optname = 75 # /usr/include/linux/in6.h

	if args.type == "SOCK_STREAM":
		type = socket.SOCK_STREAM
	elif args.type == "SOCK_DGRAM":
		type = socket.SOCK_DGRAM

	s = socket.socket(family, type)	
	s.settimeout(int(args.timeout))
	if args.transparent == True:
		s.setsockopt(level, optname, struct.pack('i', 1))
	s.bind((args.myip, int(args.myport)))
	s.listen(int(args.listen))
	try:
		s.accept()
	except:
		s.close()

def main():
	##############################
	# print usage of send.py
	##############################
	usage = "python sock.py <client|server> [PARAMS]"
	parser = ArgumentParser(usage)
	##############################
	# parse parameters of send.py
	##############################
	subparsers = parser.add_subparsers(help="python sock.py <client|server> [PARAMS]")

	parser_c = subparsers.add_parser("client", help="python sock.py client [PARAMS]")
	parser_c.set_defaults(func=client)
	common_positional(parser_c)
	common_optional(parser_c)
	parser_c.add_argument("peerip",
		action="store", help="peer IP address of the socket")
	parser_c.add_argument("peerport",
		action="store", help="peer port number of the socket")

	parser_s = subparsers.add_parser("server", help="python sock.py server [PARAMS]")
	parser_s.set_defaults(func=server)
	common_positional(parser_s)
	common_optional(parser_s)
	parser_s.add_argument("myip",
		action="store", help="my IP address of the socket")
	parser_s.add_argument("myport",
		action="store", help="my port number of the socket")
	parser_s.add_argument("--listen", dest="listen", default="5",
		action="store", help="listen second value of socket server")
	parser_s.add_argument("--transparent", dest="transparent", default="False",
		action="store_true", help="if the socket server support transparent mode")

	args = parser.parse_args()
	args.func(args)

def common_positional(parser):
	parser.add_argument("family",
		action="store", help="family of the socket [AF_INET|AF_INET6]")
	parser.add_argument("type",
		action="store", help="type of the socket [SOCK_STREAM|SOCK_DGRAM]")

def common_optional(parser):
	parser.add_argument("--timeout", dest="timeout", default="5",
		action="store", help="timeout second value of the socket")

if __name__ == "__main__":  
	main() 
