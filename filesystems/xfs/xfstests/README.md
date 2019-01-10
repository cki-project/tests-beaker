# xfstests test suite
Wrapper for xfstests test suite, see http://git.kernel.org/?p=fs/xfs/xfstests-dev.git;a=summary \
Test Maintainer: [Xiong Murphy Zhou](mailto:xzhou@redhat.com)

## How to run it

### Dependencies
Please refer to the top-level README.md for common dependencies. Test-specific dependencies will automatically be installed with dep-install.sh when you execute 'make run'. However, for a complete list of dependencies, see https://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git/tree/README 

### Configure which test cases to run, e.g.
```bash
$ export TEST_PARAM_FSTYPE=xfs
$ export TEST_PARAM_RUNTESTS=generic/001
```

### Execute the test
```bash
$ make run
```
