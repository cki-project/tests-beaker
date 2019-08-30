#!/usr/bin/python

import sys

cmd = sys.argv[1]
file = sys.argv[2]
frames = 480000
if cmd == "generate":
  fp = open(file, "wb+")
  for i in range(0, frames):
    s = i & 65535
    frame = [(s >> 8) & 255, s & 255, ((s >> 8) & 255) ^ 255, (s & 255) ^ 255]
    fp.write(bytes(frame))
  fp.close()
elif cmd == "check":
  fp = open(file, "rb")
  i = sync = 0
  while i < frames:
    frame = bytearray(fp.read(4))
    if len(frame) == 0: break
    if frame != b'\x00\x00\x00\x00': sync = 1
    if sync:
      s0 = i & 65535
      s1 = (frame[0] << 8) | frame[1]
      s2 = (frame[2] << 8) | frame[3]
      if s1 != s0:
        sys.exit(10)
      if s2 != s0 ^ 65535:
        sys.exit(11)
      i += 1
  fp.close()
  if i < frames:
    sys.exit(12)
    