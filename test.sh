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

origentry=`readelf --file-header "$2" | grep Entry | grep -o -E '0x[[:alnum:]]+'`

"$@" > ./modified_test 2>./add_code.stderr || { cat ./add_code.stderr; exit 1; }
if [[ $nofilecheck != "" ]]; then
    addr=`grep 'entry point for the ELF we added' ./add_code.stderr | grep -o -E '0x[[:alnum:]]+'`
fi
chmod a+x ./modified_test

set -o pipefail
./modified_test $nofilecheck $addr | tee ./modified_test.stdout

if [[ $3 == *"origentry"* ]]; then
    # readelf prints it without leading zeros, so we need to remove them here too
    printed_origentry=`grep -E 'in new code: original entry point:' ./modified_test.stdout | grep -o -E '0x[[:alnum:]]+' | tail -c+3`
    printed_origentry=`echo $printed_origentry | grep -o -E '[^0].*'`
    printed_origentry="0x$printed_origentry"
    if [[ $origentry != $printed_origentry ]]; then
        echo "The original entry point was not passed correctly"
        echo "Real:    $origentry"
        echo "Printed: $printed_origentry"
        exit 1
    fi
fi

rm -f ./modified_test ./modified_test.stdout ./add_code.stderr

echo '[ :-) ] Returned success! Good!'
echo
echo
