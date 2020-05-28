# Beaker tasks used with [skt](https://github.com/RH-FMK/skt) runner

## How to run tests
Here is a list of common prerequisites for all beaker tests. Test-specific dependencies and steps can be found in the README.md within each test's directory.
~~~
$ sudo wget -O /etc/yum.repos.d/beaker-client.repo https://beaker-project.org/yum/beaker-client-Fedora.repo
$ sudo wget -O /etc/yum.repos.d/beaker-harness.repo https://beaker-project.org/yum/beaker-harness-Fedora.repo
$ sudo dnf install -y beaker-client beakerlib restraint-rhts
~~~
## Test onboarding

Currently, all onboarded tests must use the following combinations of
result/status fields:

* SKIP/COMPLETED if the test requirements aren't fulfilled (eg. test is running
on incompatible architecture/hardware)
* PASS/COMPLETED if the test finished successfully
* WARN/ABORTED in case of infrastructure issues or other errors (eg. the test
checks out a git repo and the git server is unavailable)
* WARN/COMPLETED or FAIL/COMPLETED in case of any test failures, based on how
serious they are (left to decide by test authors)

See examples below to properly abort or skip in beaker:
### Abort task if infrastructure failure is task only related
~~~
if [ $? -ne 0 ]; then
    rlLog "Aborting test because $reason"
    rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
fi
~~~

### Abort recipe if infrastructure failure affects the entire recipe 
~~~
if [ $? -ne 0 ]; then
    rlLog "Aborting recipe because $reason"
    rstrnt-abort recipe
fi
~~~

### Skip the task (e.g. testing with unsupported hardware)
~~~
if [ $? -ne 0 ]; then
    rlLog "Skipping test because $reason"
    rstrnt-report-result $TEST SKIP
    exit 0
fi
~~~

When onboarding a test, please check especially the point about infrastructure
issues: a lot of tests simply report a warning if eg. external server can’t be
reached and then continue. This kind of situation falls under infrastructure
issues and the test must use the WARN/ABORTED combination, otherwise the
infrastructure problem is reported to people as a bug in their code!

The order of Beaker tasks in the XML determines if the task is a preparation for
the testing or a test. Anything after kpkginstall task is treated as a test and
must follow the rules above. Anything except PASS before kpkginstall is treated
as infrastructure issue. Machineinfo (to get HW specification) is ran before
kpkginstall, so the same logic applies there. PANIC during kpkginstall means the
kernel is bad (can't boot).

