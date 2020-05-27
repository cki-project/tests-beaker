# kvm-self-tests suite
kvm-self-tests provides self testing for KVM. The source code for
kvm-self-tests can be found at
https://git.kernel.org/pub/scm/virt/kvm/kvm.git \
Test Maintainer: [Luiz Capitulino](mailto:lcapitulino@redhat.com)

## How to run it
Please refer to the top-level README.md for common dependencies.

### Install dependencies
```bash
root# bash ../../cki_bin/pkgs_install.sh metadata
```

### Execute the test
```bash
bash ./runtest.sh
```
