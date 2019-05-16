/*
 * Copyright (c) 2019 Red Hat, Inc. All rights reserved.
 *
 * This copyrighted material is made available to anyone wishing
 * to use, modify, copy, or redistribute it subject to the terms
 * and conditions of the GNU General Public License version 2.
 *
 * This program is distributed in the hope that it will be
 * useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <string.h>

int main(int argc, char **argv)
{
	int fd = socket(PF_INET, SOCK_DGRAM, 0);
	char buf[1024] = {0};
	struct sockaddr to = {
		.sa_family = AF_UNSPEC,
		.sa_data   = "TavisIsAwesome",
	};

	// Bug 518034 - kernel: udp socket NULL ptr dereference
	sendto(fd, buf, 1024, MSG_PROXY | MSG_MORE, &to, sizeof(to));
	sendto(fd, buf, 1024, 0, &to, sizeof(to));

	return 0;
}
