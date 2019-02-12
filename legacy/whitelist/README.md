# kABI Whitelist Symbol Removal Check

Test Maintainer: [Čestmír Kalina](mailto:ckalina@redhat.com)

## Test Description

Check whether:

 - all symbols present on the kABI whitelist are exported either by vmlinux
   or a kernel module,
 - there was no kABI whitelist symbol removal.

## How to run it

Go to the test folder `/misc/whitelist/` and issue `./runtest.sh`.

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

## Execute the test
```bash
$ make run
```
