# PCI ID Removal Check

Test Maintainer: [Čestmír Kalina](mailto:ckalina@redhat.com)

## Test Description

Check that no PCI ID is removed.

## How to run it

Go to the test folder `/misc/pci_id/` and issue `./runtest.sh`.

### Dependencies

There are no outstanding dependencies beyond the tooling already
present in most RHEL systems. But to be pedantic:

## Dependencies

There are no outstanding dependencies beyond the tooling already
present in most RHEL systems. But to be pedantic:

| package       |  binaries                                                  |
|---------------|------------------------------------------------------------|
| kmod          | modinfo                                                    |
| grep          | grep                                                       |
| coreutils     | comm, mktemp, realpath, basename, dirname, sort, uniq, cat |
| rpm           | rpm, rpm2cpio                                              |
| sed           | sed                                                        |
| findutils     | find, xargs                                                |
| bash          | bash                                                       |
| cpio          | cpio                                                       |
| file          | file                                                       |
| gawk          | awk                                                        |
| binutils      | nm                                                         |
| restraint-rhts| rstrnt-report-result and friends                           |

To fetch the baseline package versions, either yum or dnf is required.

As kernel modules may be compressed, the following are required as well,
although you'll probably go by with just the first one.

| package        | binaries |
|----------------|----------|
| xz             | xzcat    |
| gzip           | zcat     |
| bzip2          | bzcat    |
| xz-lzma-compat | lzcat    |
| lzop           | lzop     |
| lz4            | lz4      |
| zstd           | unzstd   |
| tar            | tar      |

### Execute the test
```bash
$ make run
```
