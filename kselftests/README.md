# kselftest test
This is a test wrapper for [kernel selftest](https://github.com/torvalds/linux/tree/master/tools/testing/selftests) to be run in beaker test environment.

Test Maintainer: [Hangbin Liu](mailto:haliu@redhat.com)

## How to run it
Please refer to the top-level README.md for common dependencies. There are no test-specific dependencies.

### Execute the test
```bash
$ make run
```

### support tests
bpf
net
net/forwarding
tc-testing

### unsupport tests
livepatch: CONFIG_TEST_LIVEPATCH is not enabled on fedora
