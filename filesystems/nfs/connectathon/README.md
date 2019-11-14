# NFS Connectathon test suite
NFS Connectathon test suite from the Linux Test Project (LTP) http://git.linux-nfs.org/?p=steved/cthon04.git, and configured to test NFS versions 2, 3, and 4 on. This Connectathon tests run on top of an NFS mount, which tests the behavior of a real (kernel) NFS client against a server. \
Test Maintainer: [Jianhong Yin](mailto:jiyin@redhat.com)

## How to run it

### Dependencies
Please refer to the top-level README.md for common dependencies. Test-specific dependencies will automatically be installed when executing 'make run'. For a complete detail, see PURPOSE file.

### Execute the test
```bash
$ make run
```
