CC=gcc
TOOLS_DIR=.
CFLAGS=-Wall -Wextra -I$(TOOLS_DIR)

EL6 := $(shell uname -r|grep el6|wc -l)
ifeq ($(EL6),1)
	CFLAGS += -D EL6
endif

SENDERS=send_simple send_igmp_query
RECEIVERS=recv_simple recv_membership recv_source_membership recv_block_source recv_add_drop_src recv_add_block_hybrid igmp_capacity recv_group recv_msfilter
OFFLINE=sockopt_loop sockopt_ttl sockopt_if sockopt_membership sockopt_source_membership sockopt_block_source sockopt_max_groups sockopt_group sockopt_mcast_source sockopt_msfilter

all: $(SENDERS) $(RECEIVERS) $(OFFLINE)

$(SENDERS):
	$(CC) $(CFLAGS) -o $@ client/$@.c

$(RECEIVERS):
	$(CC) $(CFLAGS) -o $@ server/$@.c

$(OFFLINE):
	$(CC) $(CFLAGS) -o $@ offline/$@.c

clean:
	rm -f $(SENDERS) $(RECEIVERS) $(OFFLINE)
