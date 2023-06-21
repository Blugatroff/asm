# Calculator in x86-64 NASM for Unix

## Compile and run

```
./nasm -f elf64 -o ./main.o ./main.asm
ld ./main.o -o main
./main
```

The resulting executable is **18kB** in size, is **statically linked** and has **no dependencies**, not even *libc* or *libm*.

Unfortunately it currently doesn't support floats or doubles, only integers.

## Debug with GDB

To used gdb you need to tell nasm to include dwarf debug symbols.

```
./nasm -f elf64 -g -F dwarf -o ./main.o ./main.asm
ld ./main.o -o main
gdb ./main
```

## To dynamically link with libc

```
ld -I /lib64/ld-linux-x86-64.so.2 -lc ./main.o -o main
```

To use libc you will also need to let the libc entry point call your `main`.

```
extern __libc_start_main

_start:
    xor ebp, ebp                ; clear stack frame pointer
    mov r9, rdx                 ; 6. rtld_fini, is probably null
    pop rsi                     ; 2. argument argc
    mov rdx, rsp                ; 3. argument argv
    and rsp, 0xfffffffffffffff0 ; align stack to 16 bytes
    push rax                    ; 7. argument stack end
    xor r8, r8                  ; 5. fini function = null
    xor rcx, rcx                ; 4. init funnction = null
    mov rdi, main               ; 1. main function
    push 0                      ; return address = null
    call __libc_start_main
```

## Calling convention

I followed the SystemV calling convention. However i did not align the stack to 16 bytes before every function call. But because i never call any foreign code anyways, it doesn't matter.

I created the following, currently unused, macro for preparing the stack before calling a C function.

```
%macro call_c 1
    push rbp
    mov rbp, rsp
    and rsp, 0xFFFFFFFFFFFFFFF0
    call %1
    mov rsp, rbp
    pop rbp
%endmacro
```

## Input-Output

IO works by directly calling into the OS with system calls. Only these three syscalls are used

```
%define SYSCALL_EXIT 60
%define SYSCALL_READ 0
%define SYSCALL_WRITE 1
```

## Overview

I annoted every function with a type signature for my own sanity.

These are all the top level functions and their signatures.

```
exit: ; (rdi: code)
read: ; (rdi: fd, rsi: ptr, rdx: length) -> (rax: read|error)
write: ; (rdi: fd, rsi: ptr, rdx: length) -> (rax: written|error)

write_char: ; (rdi: fd, rsi: char) -> (rax: written|error)
write_stdout: ; (rdi: ptr, rsi: length) -> (rax: written|error)
write_char_stdout: ; (rdi: char) -> (rax: written|error)
write_newline_stdout: ; (rax: written|error)
write_indent: ; (rdi: fd)
read_stdin: ; (rdi: ptr, rsi: length) -> (rax: read|error)

print_args: ; (rdi: argc, rsi: argv)

strlen: ; (rdi: ptr) -> (rax: len)
u64_to_str: ; (rdi: ptr dst buf, rsi: n) -> (rax: len of str)
i64_to_str: ; (rdi: ptr dst buf, rsi: n) -> (rax: len of str)
str_trim_end: ; (rdi: ptr, rsi: n, dl: char to trim) -> (rsi: new length)
str_trim_start: ; (rdi: ptr, rsi: n, dl: char to trim) -> (rdi: new ptr, rsi: new len)

parse_u64: ; (rdi: ptr, rsi: len) -> (rax: n)
parse_i64: ; (rdi: ptr, rsi: len) -> (rax: n)
write_u64: ; (rdi: fd, rsi: n) -> (rax: 0|error)
write_u64_stdout: ; (rdi: n) -> (rax: 0|error)
write_i64: ; (rdi: fd, rsi: n) -> (rax: 0|error)
write_i64_stdout: ; (rdi: n) -> (rax: 0|error)

min: ; (rdi: u64, rsi: u64) -> (rax: u64)
max: ; (rdi: u64, rsi: u64) -> (rax: u64)

is_ascii_digit: ; (dil: char) -> (rax: 0|1)

init_calculator: ; (rdi: ptr calculator) -> ()

prompt: ; (rdi: ptr to name, rsi: len of name, rdx: fn parse) -> (rax: n)

operation_addition: ; () -> ()
operation_subtraction: ; () -> ()
operation_multiplication: ; () -> ()
operation_division: ; () -> ()
operation_square: ; () -> ()
operation_string: ; () -> ()

lex: ; (rdi: ptr str, rsi: len str, rdx: ptr tokens) -> (rax: number of tokens)
parse_token: ; (rdi: ptr str, rsi: len str, rdx: ptr token) -> ()
write_token_type_stdout: ; (rdi: token_type) -> ()
write_token_stdout: ; (rdi: ptr token) -> ()
write_tokens_stdout: ; (rdi: ptr tokens, rsi: len tokens)

write_expr_type_stdout: ; (rdi: expr_type) -> ()
write_expr_stdout: ; (rdi: ptr expr) -> ()

peek: ; (rdi: ptr ptr tokens, rsi: ptr len tokens) -> (rax: null|ptr token)
advance: ; (rdi: ptr ptr tokens, rsi: ptr len tokens) ->> (rax: null|ptr token)

parse_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
parse_additive_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
parse_multiplicative_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
parse_primary_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
is_additive: ; (rdi: ptr expr) -> (rax: 0|1)
is_multiplicative: ; (rdi: ptr expr) -> (rax: 0|1)
parse: ; (rdi: ptr tokens, rsi: len tokens, rdx: ptr expr) -> (rax: ptr node)

add64: ; (rdi: n, rsi: n) -> (rax: n)
sub64: ; (rdi: n, rsi: n) -> (rax: n)
mul64: ; (rdi: n, rsi: n) -> (rax: n)
idiv64: ; (rdi: a, rsi: b) -> (rax: a | b)

evaluate: ; (rdi: ptr expr) -> (rax: n)

print_operations: ; (rdi: ptr operations) -> ()
choose_operation: ; (rdi: ptr calculator) -> (rax: ptr operation)
print_chosen_operation: ; (rdi: ptr operation) -> ()

run_calculator: ; (rdi: ptr calculator) -> ()

main: ; (rdi: argc, rsi: argv) -> (rax: exit code)

_start: ; arguably not a function
```