# vxlan basic test
Basic test for vxlan: add and delete vxlan, run ping and netperf on vxlan device \
This test is supported in both single host and multi-host environment \
Test Maintainer: [Jianlin Shi](mailto:jishi@redhat.com), and [Hangbin Liu](mailto:haliu@redhat.com)

## How to run it
Please refer to the top-level README.md for common dependencies.

### Install dependencies
```bash
root# bash ../../../../cki_bin/pkgs_install.sh metadata
```

### Execute the test
```bash
bash ./runtest.sh
```
