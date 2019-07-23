#!/bin/bash

FTRACE_PREFIX="/sys/kernel/debug/tracing"
CURRENT_TRACER="${FTRACE_PREFIX}/current_tracer"
TRACING_ON="${FTRACE_PREFIX}/tracing_on"
TRACE="${FTRACE_PREFIX}/trace"

assertPass(){
$@
assertEquals '$@ failed' 0 $?
}

starttrace(){
assertPass echo 0 > ${TRACING_ON}
assertPass echo $1 > ${CURRENT_TRACER}
assertPass echo 1 > ${TRACING_ON}
}

stoptrace(){
assertPass echo 0 > ${TRACING_ON}
assertPass echo nop > ${CURRENT_TRACER}
assertPass echo > ${TRACE}
}

test_hwlat(){
tracername="hwlat"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  assertPass echo 10 > ${FTRACE_PREFIX}/tracing_thresh
  sleep 2
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

test_blk(){
tracername="blk"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 2

  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

test_mmiotrace(){
tracername="mmiotrace"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 5
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}


test_function_graph(){
tracername="function_graph"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 5
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

test_wakeup(){
tracername="wakeup"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 5
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

test_wakeup_dl(){
tracername="wakeup_dl"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 5
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

test_wakeup_rt(){
tracername="wakeup_rt"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 5
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

test_function(){
tracername="function"
if grep -q ${tracername} ${FTRACE_PREFIX}/available_tracers; then
  starttrace ${tracername}
  sleep 5
  cat ${TRACE} &> /dev/null ; rtrn=$?
  assertTrue "${tracername} trace error" ${rtrn}
  stoptrace
else
  startSkipping
fi
}

. $(dirname $0)/include
