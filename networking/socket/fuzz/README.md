This test is used for socket api fuzz testing.

Note:

Not support RHEL5 yet.

How to test:

We will create a socket randomly. If create success and in our testing type.
Then use it and run related tests.

pseudo-code:

int main(int argc, char **argv)
{
	int sockfd, family, type;

	sockfd = create_socket();

	switch(tpye) {
		case TCP:
			TCP_test(sockfd);
		case UDP:
			UDP_test(sockfd);
		default:
			do_nothing;
	}
}

int udp_test()
{
	if ( udp_server == 0 ) {
		start_udp_server(sockfd);
	} else if ( udp_client < 10 ) {
		start_udp_client(sockfd);
	}
}

int start_udp_server(int sockfd)
{
	if ( fork() != 0 )
		return 0;

	start_set_options(sockfd);

	for ( ; ; ) {
		recvmsg();
		sendto();
	}
}

TODO:

1) Add IGMP test
2) Update setopt.c

Know Issues:
