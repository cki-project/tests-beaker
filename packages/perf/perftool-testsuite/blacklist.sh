# This is a list of test exceptions for perftool-testsuite, see
# expected_result() in runtest.sh to see how it is currently used.

# format:  RESULT  ARCH,[ARCH2,]*  KERNEL_VERSION_START  KERNEL_VERSION_END  test_name
# test_name may specify a class of tests; any test containing it in the
# full name will also be considered to expect RESULT.

BLACKLIST=()

BLACKLIST+=("FAIL  aarch64,                             4.18.0      9.99.9      perf_archive :: test_basic :: archive creation")
BLACKLIST+=("FAIL  aarch64,ppc64le,s390x,x86_64,        4.18.0      9.99.9      perf_archive :: test_basic :: archive sanity (contents)")
BLACKLIST+=("FAIL  x86_64,ppc64le,                      4.18.0      9.99.9      perf_c2c")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_list :: test_basic :: basic execution (output regexp parsing)")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_list :: test_basic :: list pmu (output regexp parsing)")
BLACKLIST+=("FAIL  x86_64,ppc64le,                      4.18.0      9.99.9      perf_mem")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_probe :: test_advanced :: function string argument kprobing")
BLACKLIST+=("FAIL  aarch64,ppc64le,s390x,x86_64,        4.18.0      9.99.9      perf_record :: test_basic :: -k mono crash")
BLACKLIST+=("FAIL  s390x,aarch64,ppc64le,               4.18.0      9.99.9      perf_stat :: test_hw_breakpoints :: kspace address readwrite mem")
BLACKLIST+=("FAIL  s390x,aarch64,ppc64le,               4.18.0      9.99.9      perf_stat :: test_hw_breakpoints :: kspace address execution mem")
BLACKLIST+=("FAIL  aarch64,                             4.18.0      9.99.9      perf_stat :: test_hw :: k+u=ku check :: event")
BLACKLIST+=("FAIL  aarch64,ppc64le,s390x,x86_64,        4.18.0      9.99.9      perf_stat :: test_record_report :: diff")

BLACKLIST+=("FAIL  aarch64,                             4.18.0      9.99.9      perf_record :: test_evlist :: various events :: record bus-cycles (output regexp parsing)")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_stat :: test_powerpc_hv_24x7 :: event")
BLACKLIST+=("FAIL  s390x,                               4.18.0      9.99.9      perf_stat :: test_advanced_options :: delay event cpu-clock values OK (output regexp parsing)")

BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_probe :: test_adding_kernel :: listing added probe :: perf probe -l (output regexp parsing)")
BLACKLIST+=("FAIL  x86_64,                              4.18.0      9.99.9      perf_probe :: test_adding_kernel :: function with retval :: add")
BLACKLIST+=("FAIL  ppc64le,x86_64,                      4.18.0      9.99.9      perf_probe :: test_adding_kernel :: function with retval :: record")
BLACKLIST+=("FAIL  x86_64,                              4.18.0      9.99.9      perf_probe :: test_adding_kernel :: function argument probing :: script")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_probe :: test_advanced :: function string argument kprobing :: add (command exitcode + output regexp parsing)")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_probe :: test_listing :: kernel variables list (output regexp parsing)")
BLACKLIST+=("FAIL  ppc64le,                             4.18.0      9.99.9      perf_probe :: test_probe_syntax :: custom named probe :: list (output regexp parsing)")
