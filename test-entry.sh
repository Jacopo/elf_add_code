#!/usr/bin/env bash

set -e

echo '[ ... ] Testing' "$@"

for p in "$@"; do
    if [[ ${p:0:2} == "0x" ]]; then
        addr=$p
    fi
done

"$@" > ./modified_test 2>./add_code.stderr || { cat ./add_code.stderr; exit 1; }
addr=`grep 'entry point for the ELF we added' ./add_code.stderr | grep -o -E '0x[[:alnum:]]+'`
chmod a+x ./modified_test

set -o pipefail
./modified_test $addr | tee ./modified_test.stdout
grep -q -F 'main: I was called with argv[0]=Q' ./modified_test.stdout
rm -f ./modified_test ./modified_test.stdout ./add_code.stderr

echo '[ :-) ] Returned success! Good!'
echo
echo
