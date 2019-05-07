#!/usr/bin/env python
#encoding=utf-8
teamd_config={
	'broadcast':
	'''{
		"device": "team0",
		"runner": {
			"name": "broadcast"
		}
	}''',
	'random':
	'''{
		"device": "team0",
		"runner": {
			"name": "random"
		}
	}''',
	'roundrobin':
	'''{
		"device": "team0",
		"runner": {
			"name": "roundrobin"
		}
	}''',
	'activebackup':
	'''{
		"device": "team0",
		"runner": {
			"name": "activebackup"
		},
		"link_watch": {
			"name": "ethtool"
		}
	}''',
	'loadbalance':
	'''{
		"device": "team0",
		"runner": {
			"name": "loadbalance",
			"tx_hash": ["eth", "ipv4", "ipv6"],
			"tx_balancer": {
				"name": "basic"
			 }
		}
	}''',
	'lacp':
	'''{
		"device": "team0",
		"runner": {
			"name": "lacp",
			"active": true,
			"fast_rate": true,
			"tx_hash": ["eth", "ipv4", "ipv6"]
		},
		"link_watch": {"name": "ethtool"}
	}'''
}
link_watch_config={
	'ethtool':
	'''{
		"name": "ethtool",
		"delay_up": 2500,
		"delay_down": 1000,
	}''',
	'arp_ping':
	'''{
		"name": "arp_ping",
		"interval": 100,
		"missed_max": 30,
		"target_host": "127.0.0.1"
	}''',
	'nsna_ping':
	'''{
		"name": "nsna_ping",
		"interval": 200,
		"missed_max": 15,
		"target_host": "fe80::210:18ff:feaa:bbcc"
	}''',
}
