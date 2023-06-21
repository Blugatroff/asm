default:
    nasm -felf64 -g -F dwarf -o ./main.o ./main.asm
    ld ./main.o -o main
    ./main
