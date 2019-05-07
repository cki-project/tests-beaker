/*
 * Copyright (c) 2016-2019 Red Hat, Inc. All rights reserved.
 *
 *   This copyrighted material is made available to anyone wishing
 *   to use, modify, copy, or redistribute it subject to the terms
 *   and conditions of the GNU General Public License version 2.
 *
 *   This program is distributed in the hope that it will be
 *   useful, but WITHOUT ANY WARRANTY; without even the implied
 *   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *   PURPOSE. See the GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public
 *   License along with this program; if not, write to the Free
 *   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *   Boston, MA 02110-1301, USA.
 *
 */
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/signal.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

#define check(expr) if (!(expr)) { perror(#expr); kill(0, SIGTERM); }
int client;

void enable_keepalive(int sock, int idle, int interval, int maxpkt) {
    int yes = 1;
    check(setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, &yes, sizeof(int)) != -1);
    //overrides value (in seconds) shown by sysctl net.ipv4.tcp_keepalive_time
    check(setsockopt(sock, IPPROTO_TCP, TCP_KEEPIDLE, &idle, sizeof(int)) != -1);
    //overrides value shown by sysctl net.ipv4.tcp_keepalive_intvl
    check(setsockopt(sock, IPPROTO_TCP, TCP_KEEPINTVL, &interval, sizeof(int)) != -1);
    //overrides value shown by sysctl net.ipv4.tcp_keepalive_probes
    check(setsockopt(sock, IPPROTO_TCP, TCP_KEEPCNT, &maxpkt, sizeof(int)) != -1);
}

void handle_signal(int signum)
{
    switch(signum)
    {
        case SIGINT:
            if(close(client) != 0)
                perror("close client");
            break;
        default:
             break;
    }
}

int main(int argc, char** argv) {
    struct sigaction sig_handler;

    check(argc == 6);

    struct sockaddr_in addr;
    check(inet_pton(AF_INET, argv[1], &addr.sin_addr) != -1);
    addr.sin_family = AF_INET;
    int port= atoi(argv[2]);
    addr.sin_port = htons(port);

    int idle = atoi(argv[3]);
    int interval = atoi(argv[4]);
    int maxpkt = atoi(argv [5]);

    int server = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    check(server != -1);

    int yes = 1;
    check(setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) != -1);

    check(bind(server, (struct sockaddr*)&addr, sizeof(addr)) != -1);
    check(listen(server, 1) != -1);

    if (fork() == 0) {
        sig_handler.sa_handler = handle_signal;
        sig_handler.sa_flags = 0;

        /*Handle SIGINT in handle_signal Function*/
        if(sigaction(SIGINT, &sig_handler, NULL) == -1)
             perror("sigaction");

        client = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        check(client != -1);
        check(connect(client, (struct sockaddr*)&addr, sizeof(addr)) != -1);
        printf("connected\n");
        signal(SIGINT,handle_signal);
        pause();
    } else {
        int status;
        char command[256];

        client = accept(server, NULL, NULL);
        check(client != -1);
        enable_keepalive(client, idle, interval, maxpkt);
        printf("accepted, and block ACK from client\n");

        sprintf(command, "iptables -A INPUT -i lo -p tcp --dport %d --tcp-flags ALL ACK -j DROP", port);
        system(command);

        wait(&status);
        if(status == 0){
             printf("Child process terminated normally!\n");
             return -1;
        } else {
             printf("Child process terminated as expected - Test passed!\n");
        }
    }
    system("iptables -F");
    return 0;
}

