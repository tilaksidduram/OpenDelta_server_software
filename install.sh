#!/bin/bash
cd install/xdelta3-3.0.7
./configure
make
cp xdelta3 ../../files
cd ..
gcc -o zipadjust zipadjust.c zipadjust_run.c -lz
cp zipadjust ../files
cd ..
rm -rf install
rm -rf install.sh
