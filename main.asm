%define ALPHABET_LENGTH 26
%define ASCII_A 97
%define SYSCALL_EXIT 60
%define SYSCALL_WRITE 1
%define STDOUT 1
%define ASCII_NEWLINE 10

; . rax 1. return register
; X rbx    optionally used as base pointer
; . rcx 4. argument register
; . rdx 3. argument register, 2. return register
; X rsp stack pointer
; X rbp optionally used as frame pointer
; . rsi 2. argument register
; . rdi 1. argument register
; . r8  5. argument to function
; . r9  6. argument to function
; . r10
; . r11
; X r12
; X r13
; X r14
; X r15

global _start

section .text

write_stdout: ; accepts: rdi as pointer, rsi as length
    mov rdx, rsi
    mov rsi, rdi
    mov rax, SYSCALL_WRITE
    mov rdi, STDOUT
    syscall
    ret

print_newline:
    push ASCII_NEWLINE

    mov rdi, rsp
    mov rsi, 1
    call write_stdout

    pop rax ; pop the newline
    ret

print_alphabet:
    mov rax, 0   ; counter
    sub rsp, ALPHABET_LENGTH ; allocate space alphabet on stack

    alphabet_loop:
        mov rcx, rax
        add rcx, ASCII_A

        mov rdx, rsp             ; relative to the stack pointer
        add rdx, rax             ; add offset

        mov [rdx], cl ; store the ascii char in the buffer

        add rax, 1   ; counter += 1

        cmp rax, ALPHABET_LENGTH
        jne alphabet_loop

    mov rdi, rsp
    mov rsi, ALPHABET_LENGTH ; length of buffer
    call write_stdout

    call print_newline

    add rsp, ALPHABET_LENGTH
    ret

print_args: ; accepts rdi as argv, rsi as argc
    push r15 ; used for argc
    push r12 ; used for i
    push r13 ; used for pointer calculation
    push r14 ; used for argv

    mov r15, rsi ; store argc
    mov r12, 0
    mov r14, rdi

    print_args_loop: 
        mov rdx, r12 ; i
        shl rdx, 3   ; multiply by 8

        mov r13, r14    ; argv
        add r13, rdx    ; pointer to pointer to message
        mov r13, [r13]  ; load pointer

        mov rdi, r13 ; put pointer in rdi for call to strlen

        call strlen

        mov rsi, rax ; put ret value from strlen into 2. arg of write_stdout
        mov rdi, r13 ; put pointer int 1. arg of write_stdout
        call write_stdout

        call print_newline

        add r12, 1          ; i += 1
        cmp r12, r15
        jne print_args_loop ; if i /= argc: continue

    pop r15
    pop r14
    pop r13
    pop r12
    ret


strlen: ; accepts rdi as pointer to the str
    mov rax, 0  ; i
    strlen_loop:
        mov rdx, rdi      ; copy pointer to rdx
        add rdx, rax      ; pointer + i
        cmp byte [rdx], 0 ; *pointer == 0
        je strlen_end     ; then return i

        add rax, 1      ; i += 1
        jmp strlen_loop ; continue
    strlen_end:
    ret

_start:
    pop rsi         ; argc
    mov rdi, rsp    ; argv
    call print_args

    call print_newline
    call print_alphabet

    mov rax, SYSCALL_EXIT
    mov rdi, 0  ; exit code 0
    syscall

