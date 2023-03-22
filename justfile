default:
    nasm -felf64 -g -F dwarf -o ./main.o ./main.s
    ld -o main ./main.o
    ./main
