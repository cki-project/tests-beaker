# libhugetlbfs test suite
libhugetlbfs test provides huge pages of memory unit testing for the 
libhugetlbfs file system. The source code for libhugetlbfs wrapper can be 
found at https://github.com/libhugetlbfs/libhugetlbfs.git \
Test Maintainer: [Memory Management](mailto:mm-qe@redhat.com) 

## How to run it
Please refer to the top-level README.md for common dependencies.

### Install dependencies
```bash
root# bash ../../../cki_bin/pkgs_install.sh metadata
```

### Execute the test
```bash
bash ./runtest.sh
```
