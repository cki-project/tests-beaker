# Libkcapi AF_ALG test

Libkcapi test that exercises the AF_ALG interface and kernel Crypto API.

Test maintainer: [Ondrej Mosnacek](mailto:omosnace@redhat.com)

## How to run it
Please refer to the top-level README.md for common dependencies.

### Install dependencies
```bash
dnf install -y $(grep '^dependencies=' metadata | cut -f 2 -d = | tr ';' ' ')
```

### Execute the test
```bash
bash ./runtest.sh
```
