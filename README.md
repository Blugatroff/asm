# Program in Linux x86-64 assembly

```bash
nasm -felf64 -g -F dwarf -o ./main.o ./main.s
ld -o main ./main.o
./main
```

