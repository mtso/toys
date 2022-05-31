#!/bin/sh

# 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39
# for i in 0 1 2 3 4 5 6 7 8 9

# for i in {0..1000}
# do
#   echo "{\"event\":\"request\",\"message\":\"to 4000 hello $i $(date "+%s")\"}" | nc 0.0.0.0 4000
# done

for i in {0..10}
do
  printf "{\"event\":\"request\",\"message\":\"to 4000 hello $i $(date "+%s")\"}" | nc 0.0.0.0 4000
done
