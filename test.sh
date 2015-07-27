#!/usr/bin/env bash

set -e

echo '[ ... ] Testing' "$@"

for p in "$@"; do
    if [[ ${p:0:2} == "0x" ]]; then
        addr=$p
    elif [[ $p == *"multisection"* ]]; then
        nofilecheck="nofilecheck"
    fi
done

"$@" > ./modified_test 2>./modified_test.stderr || { cat ./modified_test.stderr; exit 1; }
if [[ $nofilecheck != "" ]]; then
    [[ $addr == "" ]]
    addr=`grep 'entry point for the ELF we added' ./modified_test.stderr | grep -o -E '0x[[:alnum:]]+'`
fi
chmod a+x ./modified_test
./modified_test $nofilecheck $addr
rm -f ./modified_test ./modified_test.stderr

echo '[ :-) ] Returned success! Good!'
echo
echo
