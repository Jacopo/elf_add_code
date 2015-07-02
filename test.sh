#!/usr/bin/env bash

set -e

echo '[ ... ] Testing' "$@"

for p in "$@"; do
    if [[ ${p:0:2} == "0x" ]]; then
        addr=$p
        break
    fi
done

"$@" > ./modified_test
chmod a+x ./modified_test
./modified_test $addr
rm -f ./modified_test

echo '[ :-) ] Returned success! Good!'
