#!/usr/bin/python

import libsan.sanmgmt as sanmgmt
import libsan.host.fcoe as fcoe
import libsan.host.dt as dt
import libsan.host.linux as linux
import libsan.misc.size as size_mod
from libsan.host.cmdline import run
import stqe.host.tc
import sys, os

TC = None

def main():
    global TC 

    TC = stqe.host.tc.TestClass()

    print("INFO: Trying to enable all SAN devices")
    obj_sanmgmt = sanmgmt.SanMgmt()
    obj_sanmgmt.setup_iscsi()
    fcoe.setup_soft_fcoe()
    
    run_dt_san_devices()

    run_dt_on_root_partition()

    if not TC.tend():
        print("FAIL: test failed")
        sys.exit(1)

    print("PASS: Test pass")
    sys.exit(0)


def run_dt_on_root_partition():
    partition = "/root"
    dt_file = "%s/dt_stress.img" % partition

    reserve_space = int(size_mod.size_human_2_size_bytes("1GiB"))
    free_space = int(linux.get_free_space(partition))
    max_size = int(size_mod.size_human_2_size_bytes("5GiB"))

    print("############################################################")
    print("INFO: Running DT Stress test on: [%s] " % partition)
    print("############################################################")
    #To avoid running for too long, do not write more than max_size
    if free_space > max_size:
        free_space = max_size

    if free_space < reserve_space:
        TC.tfail("Not enough space on %s[%d - %d]" % (partition, free_space, reserve_space))
        return False
    limit = free_space - reserve_space

    error = 0
    
    print("INFO: Starting DT stress on %s" % dt_file)
    if dt.dt_stress(of="%s" % dt_file, limit=limit):
        TC.tpass("DT wrote sucessfuly on %s" % dt_file)
    else:
        error += 1
        TC.tfail("There was some problem while running DT")
    
    run("rm -f %s" % dt_file, verbose=False)
    if error:
        return False

    return True


def run_dt_san_devices():
    dt_time = "1h"
    if "RUNTIME" in os.environ.keys():
        dt_time = os.environ['RUNTIME']

    #Get all type of SAN devices we could test
    mpaths = sanmgmt.choose_mpaths()
    if not mpaths:
        TC.tfail("Could not find any SAN device to test")
        return False

    print("############################################################")
    print("INFO: Running DT Stress test on: [%s] devices" % ", ".join(mpaths))
    print("############################################################")
    error = 0
    
    for mpath_name in mpaths.keys():
        print("INFO: Starting DT stress on %s" % mpath_name)
        if dt.dt_stress(of="/dev/mapper/%s" % mpath_name, time=dt_time):
            TC.tpass("DT stress executed sucessfuly on %s" % mpath_name)
        else:
            error += 1
            TC.tfail("There was some problem while running DT")
    if error:
        return False

    return True


main()

