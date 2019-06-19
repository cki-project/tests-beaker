# kernel-fips-mode
Test kernel FIPS 140 mode. 
Test Maintainer: [Ondrej Moris](mailto:omoris@redhat.com)

### Description
Test enables FIPS mode and reboot the system to boot into FIPS mode. After successful boot FIPS mode is disabled again.

### How to run it
Please refer to the top-level README.md for common dependencies. Test-specific dependencies will automatically be installed when executing 'make run'. For a complete detail, see PURPOSE file.

### Execute the test
```bash
$ make run
```
### Warning 
This test might be potentially destructive because any FIPS issue in kernel usually causes kernel panic and breaks subsequent testing. Therefore it is recommended to either run this test in isolation or to run it as the last test.
