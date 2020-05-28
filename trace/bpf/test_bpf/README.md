# Testing bpf using the test_bpf kernel module

The aim of this test is to make sure bpf works by loading the test_bpf kernel module.

## How to run this test
First, follow the common steps to setup the required test lib
~~~
$ sudo wget -O /etc/yum.repos.d/beaker-client.repo https://beaker-project.org/yum/beaker-client-Fedora.repo
$ sudo wget -O /etc/yum.repos.d/beaker-harness.repo https://beaker-project.org/yum/beaker-harness-Fedora.repo
$ sudo dnf install -y beaker-client beakerlib restraint
~~~

Then it's as easy as run the script `runtest.sh`.
