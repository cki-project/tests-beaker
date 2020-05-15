# loopdevice sanity test suite
Sanity test suite for loop device. This test will mount various filesystems, and stress them through iozone. \
Test Maintainer: [Xiong Zhou](mailto:xzhou@redhat.com)

## How to run it

### Dependencies
Please refer to the top-level README.md for common dependencies.

### Install dependencies
```bash
root# bash ../../cki_bin/pkgs_install.sh metadata
```

### Execute the test
```bash
bash ./runtest.sh
```
