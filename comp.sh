#!/bin/bash
rm -f *.tap
rm -f *.bin
rm -f *_linux 
ZXTEMP=/tmp/zx_temp/
rm -fr $ZXTEMP
mkdir -p $ZXTEMP

# Reference Run
gcc -Wall -O3 -g train.c -o train_float_linux || exit 1
./train_float_linux || exit 1 # also creates 
gcc -Wall -O3 -g train_f16.c -o train_16_linux || exit 1
./train_16_linux || exit 1 

# zcc build
zcc +zx -vn -O3 -zorg=25600 -startup=31 -clib=sdcc_iy train.c -lm -o $ZXTEMP/train || exit 1
appmake +zx -b $ZXTEMP/train_CODE.bin -o code.tap --blockname dl --org 25600 --noloader || exit 1 

zcc +zx -vn -O3 -zorg=25600 -startup=0 -clib=sdcc_iy train_f16.c -lm -o $ZXTEMP/train_16 || exit 1
appmake +zx -b $ZXTEMP/train_16_CODE.bin -o code_16.tap --blockname dl --org 25600 --noloader || exit 1

# make asm loader for data screen block
z80asm -b -o$ZXTEMP/load_data.bin load.asm || exit 1
python bin_to_data.py $ZXTEMP/load_data.bin >$ZXTEMP/load_screen.bas

# make C loader
gcc -Wall print_epochs_no.c -o $ZXTEMP/print_epochs_no || exit 1
$ZXTEMP/print_epochs_no | cat loader.bas - $ZXTEMP/load_screen.bas  >$ZXTEMP/c_loader.bas 
bas2tap -sloader -a1 $ZXTEMP/c_loader.bas c_code_loader.tap

# make tapes for all
cat c_code_loader.tap code.tap train_screen.tap test_screen.tap >train_C_float.tap
cat c_code_loader.tap code_16.tap train_screen.tap test_screen.tap >train_C_fixed.tap


# make basic code
bas2tap -slearn -a1 train.bas basic_code.tap || exit 1
cat basic_code.tap train_and_test_screen.tap >train_basic.tap
bas2tap -slearn <(cat train.bas | grep -v LOAD) basic_code_for_tobos.tap || exit 1
cat basic_code_for_tobos.tap train_and_test_screen.tap >train_basic_tobos.tap



