# networking/socket/fuzz
This suite provides socket api fuzz testing.
Test Maintainer: [Hangbin Liu](mailto:haliu@redhat.com)

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

## TODO
1. Add IGMP support
1. Add SCTP support
1. Add IPv6 support
1. Let server/client close socket randomly
