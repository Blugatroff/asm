%define ALPHABET_LENGTH 26

%define ASCII_NEWLINE 10
%define ASCII_SPACE 32
%define ASCII_QUOTE 34
%define ASCII_LEFT_PAREN 40
%define ASCII_RIGHT_PAREN 41
%define ASCII_STAR 42
%define ASCII_PLUS 43
%define ASCII_COMMA 44
%define ASCII_MINUS 45
%define ASCII_SLASH 47
%define ASCII_0 48
%define ASCII_COLON 58
%define ASCII_GREATER_THAN 62
%define ASCII_LEFT_BRACKET 91
%define ASCII_RIGHT_BRACKET 93
%define ASCII_A 97
%define ASCII_F 102
%define ASCII_M 109
%define ASCII_P 112

%define SYSCALL_EXIT 60
%define SYSCALL_READ 0
%define SYSCALL_WRITE 1
%define STDIN 0
%define STDOUT 1

%define OPERATIONS_LEN 1

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

; extern malloc
; extern free
; extern memset
; extern memcpy
; extern memcmp
; extern __libc_start_main

global _start
section .text

%macro call_c 1
    push rbp
    mov rbp, rsp
    and rsp, 0xFFFFFFFFFFFFFFF0
    call %1
    mov rsp, rbp
    pop rbp
%endmacro

%macro enter 1
    push rbp
    mov rbp, rsp
    sub rsp, %1
%endmacro

return:
    ret

exit: ; (rdi: code)
    mov rax, SYSCALL_EXIT
    syscall

read: ; (rdi: fd, rsi: ptr, rdx: length) -> (rax: read|error)
    mov rax, SYSCALL_READ
    syscall
    ret


write: ; (rdi: fd, rsi: ptr, rdx: length) -> (rax: written|error)
    mov rax, SYSCALL_WRITE
    syscall
    ret

write_char: ; (rdi: fd, rsi: char) -> (rax: written|error)
    push rsi
    mov rsi, rsp
    mov rdx, 1
    call write
    pop rsi
    ret

write_stdout: ; (rdi: ptr, rsi: length) -> (rax: written|error)
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, STDOUT
    call write
    ret

write_char_stdout: ; (rdi: char) -> (rax: written|error)
    mov rsi, rdi
    mov rdi, STDOUT
    call write_char
    ret

read_stdin: ; (rdi: ptr, rsi: length) -> (rax: read|error)
    mov rdx, rsi
    mov rsi, rdi
    mov rdi, STDIN
    call read
    ret

write_newline_stdout: ; (rax: written|error)
    push ASCII_NEWLINE

    mov rdi, rsp
    mov rsi, 1
    call write_stdout

    pop rdi ; pop the newline
    ret

print_args: ; (rdi: argc, rsi: argv)
    push r12 ; used for i
    push r13 ; used for pointer calculation
    push r14 ; used for argv
    push r15 ; used for argc

    mov r15, rdi ; store argc
    mov r12, 0
    mov r14, rsi ; store argv

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

        call write_newline_stdout 

        add r12, 1          ; i += 1
        cmp r12, r15
        jne print_args_loop ; if i /= argc: continue

    pop r15
    pop r14
    pop r13
    pop r12
    ret


strlen: ; (rdi: ptr) -> (rax: len)
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

u64_to_str: ; (rdi: ptr dst buf, rsi: n) -> (rax: len of str)
    sub rsp, 32 ; rsp is buf
    mov r8, 0   ; length of str
    mov r9, 0   ; i
    
    cmp rsi, 0
    jne u64_to_str_loop
    mov r8, 1 ; length = 1
    mov byte [rsp], 48

    jmp u64_to_str_buf_reverse
    
    u64_to_str_loop:
        cmp rsi, 0
        je u64_to_str_buf_reverse

        mov r10, rsp
        add r10, r8      ; + l

        xor rdx, rdx     ; clear upper 64 bits of dividend
        mov rax, rsi     ; put n in lower 64 bits dividend
        mov r11, 10
        div r11          ; remainder in rdx, quotient in rax
        add rdx, ASCII_0

        mov byte [r10], dl ; store the char in buf, al = 8bit rax
        
        mov rsi, rax ; n = n / 10
        add r8, 1    ; length += 1

        jmp u64_to_str_loop 
    

    u64_to_str_buf_reverse:

    mov r9, 0 ; i = 0
    u64_to_str_reverse_loop:
        mov r10, rdi ; bufptr
        add r10, r9  ; bufptr + i
        
        mov r11, r8        ; length
        sub r11, r9        ; - length
        sub r11, 1
        add r11, rsp       ; + bufptr
        mov al, [r11]      ; load the char
        mov byte [r10], al
        
        add r9, 1
        cmp r9, r8
        jne u64_to_str_reverse_loop
    
    add rsp, 32
    mov rax, r8
    ret

i64_to_str: ; (rdi: ptr dst buf, rsi: n) -> (rax: len of str)
    push r12
    
    mov r12, 1
    shl r12, 63
    
    and r12, rsi
    cmp r12, 0
    je i64_to_str_pos
    
    mov byte [rdi], ASCII_MINUS

    add rdi, 1
    neg rsi
    call u64_to_str
    add rax, 1
    jmp i64_to_str_end

    i64_to_str_pos:
        call u64_to_str
        jmp i64_to_str_end

    i64_to_str_end:
    pop r12
    ret

parse_u64: ; (rdi: ptr, rsi: len) -> (rax: n)
    push rdi
    push rsi
    mov r8, rdi ; ptr
    mov r9, rsi ; len
    mov rax, 0  ; n

    parse_u64_loop:
        mov bl, byte [r8] ; load digit

        cmp bl, 48          ; char < 48
        jl parse_failed
        cmp bl, 58          ; char > 58
        jg parse_failed

        sub bl, 48       ; ASCII -> 0-9
        movzx rcx, bl
        add rax, rcx     ; store digit in n
        add r8, 1        ; advance pointer
        sub r9, 1        ; reduce length
        cmp r9, 0        ; if length == 0
        je parse_u64_end ; return

        imul rax, 10
        jmp parse_u64_loop
    
    parse_u64_end: 
    pop rsi
    pop rdi
    ret

parse_failed:
    mov rdi, PARSING_FAILED
    mov rsi, PARSING_FAILED_LEN
    call write_stdout

    mov rdi, ASCII_QUOTE
    call write_char_stdout

    pop rsi
    pop rdi
    call write_stdout

    mov rdi, ASCII_QUOTE
    call write_char_stdout

    call write_newline_stdout
    mov rdi, 1
    call exit


parse_i64: ; (rdi: ptr, rsi: len) -> (rax: n)
    cmp rsi, 0
    je parse_i64_empty

    cmp byte [rdi], ASCII_MINUS
    je parse_i64_negative
    call parse_u64
    ret
    parse_i64_negative:
        add rdi, 1
        sub rsi, 1
        call parse_u64
        neg rax
        ret
    parse_i64_empty:
        push rdi
        push rsi
        jmp parse_failed

write_u64: ; (rdi: fd, rsi: n) -> (rax: 0|error)
    push r12     ; fd
    enter 32     ; allocate 32 bytes
    mov r12, rdi ; fd

    mov rdi, rsp    ; ptr
    mov rsi, rsi    ; rsi already populated
    call u64_to_str
    mov r9, rax     ; store length of number

    mov rdi, r12 ; fd
    mov rsi, rsp ; ptr
    mov rdx, r9  ; length
    call write

    leave
    pop r12
    ret

write_u64_stdout: ; (rdi: n) -> (rax: 0|error)
    mov rsi, rdi
    mov rdi, STDOUT
    call write_u64
    ret

write_i64: ; (rdi: fd, rsi: n) -> (rax: 0|error)
    push r12     ; fd
    enter 32     ; allocate 32 bytes
    mov r12, rdi ; fd

    mov rdi, rsp    ; ptr
    mov rsi, rsi    ; rsi already populated
    call i64_to_str
    mov r9, rax     ; store length of number

    mov rdi, r12 ; fd
    mov rsi, rsp ; ptr
    mov rdx, r9  ; length
    call write

    leave
    pop r12
    ret

write_i64_stdout: ; (rdi: n) -> (rax: 0|error)
    mov rsi, rdi
    mov rdi, STDOUT
    call write_i64
    ret


; not following System-V
str_trim_end: ; (rdi: ptr, rsi: n, dl: char to trim) -> (rsi: new length)
    cmp rsi, 0
    je str_trim_end_end

    str_trim_end_loop:
        mov bl, [rdi + rsi - 1]
        cmp bl, dl
        jne str_trim_end_end
        sub rsi, 1
        jmp str_trim_end_loop

    str_trim_end_end:
    ret

; not following System-V
str_trim_start: ; (rdi: ptr, rsi: n, dl: char to trim) -> (rdi: new ptr, rsi: new len)
    cmp rsi, 0
    je str_trim_start_end

    str_trim_start_loop:
        mov bl, [rdi]
        cmp bl, dl
        jne str_trim_start_end
        add rdi, 1
        sub rsi, 1
        jmp str_trim_start_loop

    str_trim_start_end:
    ret

min: ; (rdi: u64, rsi: u64) -> (rax: u64)
    cmp rdi, rsi
    jl min_a_is_lower
    mov rax, rsi
    ret
    min_a_is_lower:
        mov rax, rdi
        ret

max: ; (rdi: u64, rsi: u64) -> (rax: u64)
    cmp rdi, rsi
    jg max_a_is_greater
    mov rax, rsi
    ret
    max_a_is_greater:
        mov rax, rdi
        ret

is_ascii_digit: ; (dil: char) -> (rax: 0|1)
    mov rax, 0

    cmp dil, 48
    jl return
    
    cmp dil, 57
    jg return

    mov rax, 1
    ret

%define SIZEOF_OPERATION 24
; operation:
;   name:     *char
;   name-len: u64
;   function: () -> (rax: 0/error)

; mov r8, 5   ; len(Operations)
; imul r8, 24 ; * sizeof(Operation)
; add r8, 8   ; + 8 for storing the length
%define CALCULATOR_SIZE (6 * SIZEOF_OPERATION + 8)

init_calculator: ; (rdi: ptr calculator) -> ()
    mov r8, rdi
    mov qword [r8], 6 ; number of ops
    add r8, 8
    mov qword [r8], ADDITION_NAME
    mov qword [r8 + 8], ADDITION_NAME_LEN
    mov qword [r8 + 16], operation_addition
    add r8, SIZEOF_OPERATION
    mov qword [r8], SUBTRACTION_NAME
    mov qword [r8 + 8], SUBTRACTION_NAME_LEN
    mov qword [r8 + 16], operation_subtraction
    add r8, SIZEOF_OPERATION
    mov qword [r8], MULTIPLICATION_NAME
    mov qword [r8 + 8], MULTIPLICATION_NAME_LEN
    mov qword [r8 + 16], operation_multiplication
    add r8, SIZEOF_OPERATION
    mov qword [r8], DIVISION_NAME
    mov qword [r8 + 8], DIVISION_NAME_LEN
    mov qword [r8 + 16], operation_division
    add r8, SIZEOF_OPERATION
    mov qword [r8], SQUARE_NAME
    mov qword [r8 + 8], SQUARE_NAME_LEN
    mov qword [r8 + 16], operation_square
    add r8, SIZEOF_OPERATION
    mov qword [r8], STRING_MODE_NAME
    mov qword [r8 + 8], STRING_MODE_NAME_LEN
    mov qword [r8 + 16], operation_string

    ret

prompt: ; (rdi: ptr to name, rsi: len of name, rdx: fn parse) -> (rax: n)
    enter 32
    push r12
    mov r12, rdx

    call write_stdout      ; (args already setup)
    mov rdi, ASCII_GREATER_THAN
    call write_char_stdout
    mov rdi, ASCII_SPACE
    call write_char_stdout

    mov rdi, rbp
    mov rsi, 32
    call read_stdin

    mov rdi, rbp
    mov rsi, rax
    mov dl, ASCII_NEWLINE
    call str_trim_end
    call r12     ; call parse function -> n in rax

    pop r12
    leave
    ret

operation_addition: ; () -> ()
    push r12 ; number 1
    push r13 ; number 2

    mov rdi, NUMBER_ONE
    mov rsi, NUMBER_ONE_LEN
    mov rdx, parse_i64
    call prompt
    mov r12, rax

    mov rdi, NUMBER_TWO
    mov rsi, NUMBER_TWO_LEN
    mov rdx, parse_i64
    call prompt
    mov r13, rax

    mov rdi, r12
    add rdi, r13
    call write_u64_stdout
    call write_newline_stdout
    
    pop r13
    pop r12
    ret

operation_subtraction: ; () -> ()
    push r12 ; number 1
    push r13 ; number 2

    mov rdi, NUMBER_ONE
    mov rsi, NUMBER_ONE_LEN
    mov rdx, parse_i64
    call prompt
    mov r12, rax

    mov rdi, NUMBER_TWO
    mov rsi, NUMBER_TWO_LEN
    mov rdx, parse_i64
    call prompt
    mov r13, rax

    mov rdi, r12
    sub rdi, r13
    call write_i64_stdout
    call write_newline_stdout
    
    pop r13
    pop r12
    ret

operation_multiplication: ; () -> ()
    push r12 ; number 1
    push r13 ; number 2

    mov rdi, NUMBER_ONE
    mov rsi, NUMBER_ONE_LEN
    mov rdx, parse_i64
    call prompt
    mov r12, rax

    mov rdi, NUMBER_TWO
    mov rsi, NUMBER_TWO_LEN
    mov rdx, parse_i64
    call prompt
    mov r13, rax

    mov rdi, r12
    imul rdi, r13
    call write_i64_stdout
    call write_newline_stdout
    
    pop r13
    pop r12
    ret

idiv64: ; (rdi: a, rsi: b) -> (rax: a | b)
    mov rax, rdi
    cqo
    idiv rsi
    ret

operation_division: ; () -> ()
    push r12 ; number 1
    push r13 ; number 2

    mov rdi, NUMBER_ONE
    mov rsi, NUMBER_ONE_LEN
    mov rdx, parse_i64
    call prompt
    mov r12, rax

    mov rdi, NUMBER_TWO
    mov rsi, NUMBER_TWO_LEN
    mov rdx, parse_i64
    call prompt
    mov r13, rax

    mov rdi, r12
    mov rsi, r13
    call idiv64

    mov rdi, rax
    call write_i64_stdout
    call write_newline_stdout
    
    pop r13
    pop r12
    ret

operation_square: ; () -> ()
    mov rdi, NUMBER_ONE
    mov rsi, NUMBER_ONE_LEN
    mov rdx, parse_i64
    call prompt
    mov rdi, rax

    imul rdi, rdi

    call write_i64_stdout
    call write_newline_stdout
    ret

operation_string: ; () -> ()
    push r12 ; number of tokens
    push r13 ; ptr ast node
    sub rsp, 3072

    mov rdi, ASCII_GREATER_THAN
    call write_char_stdout

    mov rdi, ASCII_SPACE
    call write_char_stdout

    mov rdi, rsp    ; allocated buffer
    mov rsi, 1024   ; first 1024 bytes
    call read_stdin
    
    mov rdi, rsp  ; pointer to line
    mov rsi, rax  ; length of line
    mov rdx, rsp  ; allocated buffer
    add rdx, 1024 ; ptr tokens
    call lex
    mov r12, rax  ; number of tokens

    mov rdi, rsp  ; allocated buffer
    add rdi, 1024 ; ptr tokens
    mov rsi, r12  ; number of tokens
    mov rdx, rsp  ; allocated buffer
    add rdx, 2048 ; ptr exprs
    call parse
    mov r13, rax  ; ptr ast node

    mov rdi, r13  ; ptr ast node
    call evaluate ; result in rax

    mov rdi, rax
    call write_i64_stdout

    mov dil, ASCII_NEWLINE
    call write_char_stdout

    pop r13
    pop r12
    add rsp, 3072
    ret

%define SIZEOF_TOKEN 32
%define TOKEN_TYPE 0
%define TOKEN_NUMBER 8
%define TOKEN_LEXEME_PTR 16
%define TOKEN_LEXEME_LEN 24

%define TOKEN_TYPE_NUMBER 1
%define TOKEN_TYPE_PLUS 2
%define TOKEN_TYPE_MINUS 3
%define TOKEN_TYPE_STAR 4
%define TOKEN_TYPE_SLASH 5
%define TOKEN_TYPE_LEFT_PAREN 6
%define TOKEN_TYPE_RIGHT_PAREN 7

; token:
;   type:   u64
;   number: u64
;   lexeme_ptr: ptr str
;   lexeme_len: u64

lex: ; (rdi: ptr str, rsi: len str, rdx: ptr tokens) -> (rax: number of tokens)
    push r12 ; ptr str
    push r13 ; len str
    push r14 ; ptr tokens
    push r15 ; previous was number
    mov r12, rdi ; ptr str
    mov r13, rsi ; len str
    mov r14, rdx ; ptr tokens
    mov r15, 0 ; previous was digit

    mov rdx, 0 ; i
    mov r8 , 0 ; cursor
    mov rax, 0 ; n tokens

    lex_loop:
        cmp rdx, r13
        je lex_loop_reached_end

        mov r9b, byte [r12 + rdx] ; char

        mov rdi, 0 ; is digit

        mov dil, r9b         ; put char in rdi
        push rdx
        push r8
        push rax
        call is_ascii_digit
        mov rdi, rax
        pop rax
        pop r8
        pop rdx
        cmp rdi, 1 ; is digit
        je lex_loop_found_delimiter

        mov r15, 0 ; previous was digit = false

        cmp r9b, ASCII_SPACE
        je lex_loop_found_delimiter
        cmp r9b, ASCII_LEFT_PAREN
        je lex_loop_found_delimiter
        cmp r9b, ASCII_RIGHT_PAREN
        je lex_loop_found_delimiter
        cmp r9b, ASCII_PLUS
        je lex_loop_found_delimiter
        cmp r9b, ASCII_MINUS
        je lex_loop_found_delimiter
        cmp r9b, ASCII_STAR
        je lex_loop_found_delimiter
        cmp r9b, ASCII_SLASH
        je lex_loop_found_delimiter

        jmp lex_loop_done

        lex_loop_found_delimiter:
            push rdi
            call lex_loop_add_token
            pop rdi
            mov r15, rdi
            jmp lex_loop_done

        lex_loop_done:
        add rdx, 1   ; i += 1
        jmp lex_loop

        lex_loop_add_token: ; (rdi: is digit)
            and rdi, r15 ; is digit and previous was digit
            cmp rdi, 1
            je return

            push rdx
            push r8
            push rax

            mov rdi, r12           ; ptr str
            add rdi, r8            ; ptr str + cursor = ptr
            mov rsi, rdx           ; i
            sub rsi, r8            ; i - cursor = len

            mov dl, ASCII_SPACE
            call str_trim_end
            mov dl, ASCII_NEWLINE
            call str_trim_end
            mov dl, ASCII_SPACE
            call str_trim_start

            cmp rsi, 0
            je lex_loop_add_token_done

            imul rax, SIZEOF_TOKEN ; n tokens * SIZEOF_TOKEN = offset
            mov rdx, r14           ; ptr tokens
            add rdx, rax           ; ptr tokens + offset = ptr token
            call parse_token
            
            pop rax
            add rax, 1 ; n tokens += 1
            push rax
            lex_loop_add_token_done:
            pop rax
            pop r8
            pop rdx

            mov r8, rdx ; cursor = i
            ret

        lex_loop_reached_end:
            call lex_loop_add_token
            jmp lex_done

    lex_done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

parse_token: ; (rdi: ptr str, rsi: len str, rdx: ptr token) -> ()
    cmp rsi, 0
    je parse_token_failed

    mov qword [rdx + TOKEN_LEXEME_PTR], rdi
    mov qword [rdx + TOKEN_LEXEME_LEN], rsi
    
    push r12 ; ptr str
    push r13 ; len str
    mov r12, rdi
    mov r13, rsi

    cmp byte [rdi], ASCII_LEFT_PAREN
    je parse_token_left_paren
    cmp byte [rdi], ASCII_RIGHT_PAREN
    je parse_token_right_paren
    cmp byte [rdi], ASCII_PLUS
    je parse_token_plus
    cmp byte [rdi], ASCII_MINUS
    je parse_token_minus
    cmp byte [rdi], ASCII_STAR
    je parse_token_star
    cmp byte [rdi], ASCII_SLASH
    je parse_token_slash

    mov dil, byte [rdi]
    call is_ascii_digit
    cmp rax, 1
    je parse_token_number

    parse_token_left_paren:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_LEFT_PAREN
        jmp parse_token_end
    parse_token_right_paren:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_RIGHT_PAREN
        jmp parse_token_end
    parse_token_plus:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_PLUS
        jmp parse_token_end
    parse_token_minus:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_MINUS
        jmp parse_token_end
    parse_token_star:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_STAR
        jmp parse_token_end
    parse_token_slash:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_SLASH
        jmp parse_token_end
    parse_token_number:
        mov qword [rdx + TOKEN_TYPE], TOKEN_TYPE_NUMBER
        mov rdi, r12
        mov rsi, r13
        call parse_u64
        mov qword [rdx + TOKEN_NUMBER], rax
        jmp parse_token_end
    parse_token_end:
    pop r13
    pop r12
    ret
    parse_token_failed:
        mov rdi, 1
        call exit

write_token_type_stdout: ; (rdi: token_type) -> ()
    cmp rdi, TOKEN_TYPE_NUMBER
    je write_token_type_stdout_number
    cmp rdi, TOKEN_TYPE_LEFT_PAREN
    je write_token_type_stdout_left_paren
    cmp rdi, TOKEN_TYPE_RIGHT_PAREN
    je write_token_type_stdout_right_paren
    cmp rdi, TOKEN_TYPE_PLUS
    je write_token_type_stdout_plus
    cmp rdi, TOKEN_TYPE_MINUS
    je write_token_type_stdout_minus
    cmp rdi, TOKEN_TYPE_STAR
    je write_token_type_stdout_star
    cmp rdi, TOKEN_TYPE_SLASH
    je write_token_type_stdout_slash

    call write_u64_stdout ; TODO: make this crash with nice error
    ret

    write_token_type_stdout_number:
        mov rdi, TOKEN_TYPE_NUMBER_STR
        mov rsi, TOKEN_TYPE_NUMBER_STR_LEN
        call write_stdout
        ret
    write_token_type_stdout_left_paren:
        mov rdi, TOKEN_TYPE_LEFT_PAREN_STR
        mov rsi, TOKEN_TYPE_LEFT_PAREN_STR_LEN
        call write_stdout
        ret
    write_token_type_stdout_right_paren:
        mov rdi, TOKEN_TYPE_RIGHT_PAREN_STR
        mov rsi, TOKEN_TYPE_RIGHT_PAREN_STR_LEN
        call write_stdout
        ret
    write_token_type_stdout_plus:
        mov rdi, TOKEN_TYPE_PLUS_STR
        mov rsi, TOKEN_TYPE_PLUS_STR_LEN
        call write_stdout
        ret
    write_token_type_stdout_minus:
        mov rdi, TOKEN_TYPE_MINUS_STR
        mov rsi, TOKEN_TYPE_MINUS_STR_LEN
        call write_stdout
        ret
    write_token_type_stdout_star:
        mov rdi, TOKEN_TYPE_STAR_STR
        mov rsi, TOKEN_TYPE_STAR_STR_LEN
        call write_stdout
        ret
    write_token_type_stdout_slash:
        mov rdi, TOKEN_TYPE_SLASH_STR
        mov rsi, TOKEN_TYPE_SLASH_STR_LEN
        call write_stdout
        ret

write_token_stdout: ; (rdi: ptr token) -> ()
    push r12
    mov r12, rdi
    
    mov rdi, ASCII_LEFT_PAREN
    call write_char_stdout

    mov rdi, ASCII_QUOTE
    call write_char_stdout
    mov rdi, [r12 + TOKEN_LEXEME_PTR]
    mov rsi, [r12 + TOKEN_LEXEME_LEN]
    call write_stdout
    mov rdi, ASCII_QUOTE
    call write_char_stdout

    mov rdi, ASCII_COLON
    call write_char_stdout
    
    mov rdi, ASCII_SPACE
    call write_char_stdout

    mov rdi, [r12 + TOKEN_TYPE]
    call write_token_type_stdout
    
    cmp qword [r12 + TOKEN_TYPE], TOKEN_TYPE_NUMBER
    je write_token_stdout_number

    jmp write_token_stdout_end

    write_token_stdout_number:
        mov rdi, ASCII_SPACE
        call write_char_stdout
        mov rdi, [r12 + TOKEN_NUMBER]
        call write_u64_stdout
        jmp write_token_stdout_end

    write_token_stdout_end:
    mov rdi, ASCII_RIGHT_PAREN
    call write_char_stdout

    pop r12
    ret

write_tokens_stdout: ; (rdi: ptr tokens, rsi: len tokens)
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, 0
    write_tokens_stdout_loop:
        cmp r14, r13  ; i == len
        je write_tokens_stdout_done
        
        mov rdi, r14           ; i
        imul rdi, SIZEOF_TOKEN
        add rdi, r12           ; ptr tokens
        call write_token_stdout

        mov rdi, ASCII_NEWLINE
        call write_char_stdout
    
        add r14, 1     ; i += 1
        jmp write_tokens_stdout_loop

    write_tokens_stdout_done:
    pop r14
    pop r13
    pop r12
    ret

%define SIZEOF_EXPR 32
%define EXPR_TYPE 0
%define EXPR_LEFT 8
%define EXPR_RIGHT 16
%define EXPR_NUMBER 24

%define EXPR_TYPE_GROUP TOKEN_TYPE_LEFT_PAREN
%define EXPR_TYPE_NUMBER TOKEN_TYPE_NUMBER

; expr:
;   type:   u64
;   left:   ptr expr
;   right:  ptr expr
;   number: u64

write_expr_type_stdout: ; (rdi: expr_type) -> ()
    call write_u64_stdout
    ret

write_expr_stdout: ; (rdi: ptr expr) -> ()
    cmp qword [rdi + EXPR_TYPE], EXPR_TYPE_GROUP
    je write_expr_stdout_group
    cmp qword [rdi + EXPR_TYPE], EXPR_TYPE_NUMBER
    je write_expr_stdout_number
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_PLUS
    je write_expr_stdout_binary
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_MINUS
    je write_expr_stdout_binary
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_STAR
    je write_expr_stdout_binary
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_SLASH
    je write_expr_stdout_binary

    mov rdi, [rdi + EXPR_TYPE]
    call write_u64_stdout

    ret

    write_expr_stdout_group:
        push rdi
        mov dil, ASCII_LEFT_PAREN
        call write_char_stdout
        pop rdi
        mov rdi, [rdi + EXPR_LEFT]
        call write_expr_stdout

        mov dil, ASCII_RIGHT_PAREN
        call write_char_stdout
        ret

    write_expr_stdout_number:
        mov rdi, [rdi + EXPR_NUMBER]
        call write_u64_stdout
        ret
    write_expr_stdout_binary: ; (rdi: ptr expr) -> ()
        push r12
        mov r12, rdi

        mov dil, ASCII_LEFT_PAREN
        call write_char_stdout

        mov rdi, [r12 + EXPR_LEFT]
        call write_expr_stdout

        mov dil, ASCII_SPACE
        call write_char_stdout

        mov rdi, [r12 + EXPR_TYPE]
        call write_token_type_stdout

        mov dil, ASCII_SPACE
        call write_char_stdout
        
        mov rdi, [r12 + EXPR_RIGHT]
        call write_expr_stdout

        mov dil, ASCII_RIGHT_PAREN
        call write_char_stdout

        pop r12
        ret

peek: ; (rdi: ptr ptr tokens, rsi: ptr len tokens) -> (rax: null|ptr token)
    mov rax, 0
    cmp qword [rsi], 0
    je return
    mov rax, [rdi]
    ret

advance: ; (rdi: ptr ptr tokens, rsi: ptr len tokens) ->> (rax: null|ptr token)
    mov rax, 0
    cmp rsi, 0
    je return
    mov rax, [rdi]
    add qword [rdi], SIZEOF_TOKEN
    sub qword [rsi], 1
    ret

; https://en.wikipedia.org/wiki/Operator-precedence_parser#Precedence_climbing_method
parse_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
    call parse_additive_expression
    ret

parse_additive_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi ; ptr tokens
    mov r13, rsi ; len tokens
    mov r14, rdx ; ptr expr
    mov r15, 0   ; ptr expr | ptr token
    call parse_multiplicative_expression
    cmp rax, 0                           ; parse_multiplicative_expression failed
    je parse_additive_expression_fail    ; in case of failure
    mov r14, rax
     
    parse_additive_expression_loop:
        mov rdi, r12
        mov rsi, r13
        call peek
        mov r15, rax ; next

        cmp r15, 0                          ; if next is null
        je parse_additive_expression_return ; return

        mov rdi, r15
        call is_additive
        cmp rax, 0                          ; if next is not additive
        je parse_additive_expression_return ; retur

        mov rdi, r12
        mov rsi, r13
        call advance
        mov r15, rax ; op
        cmp r15, 0
        je parse_additive_expression_fail

        mov rdi, r12
        mov rsi, r13
        mov rdx, r14
        add rdx, SIZEOF_EXPR
        call parse_multiplicative_expression

        mov rdx, rax
        add rdx, SIZEOF_EXPR        ; new expr
        mov r8, [r15 + TOKEN_TYPE]
        mov [rdx + EXPR_TYPE], r8
        mov [rdx + EXPR_LEFT], r14  ; expr
        mov r8, r14
        add r8, SIZEOF_EXPR
        mov [rdx + EXPR_RIGHT], r8 ; right

        mov r14, rdx ; expr = new expr

        jmp parse_additive_expression_loop

    parse_additive_expression_fail:
    mov rax, 0                        ; null
    jmp parse_additive_expression_end

    parse_additive_expression_return:
    mov rax, r14 ; ptr expr
    parse_additive_expression_end:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

parse_multiplicative_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi ; ptr ptr tokens
    mov r13, rsi ; ptr len tokens
    mov r14, rdx ; ptr expr
    mov r15, 0   ; ptr expr | ptr token

    call parse_primary_expression
    cmp rax, 0                              ; parse_primary_expression failed
    je parse_multiplicative_expression_fail ; in case of failure
    mov r14, rax
     
    parse_multiplicative_expression_loop:
        mov rdi, r12
        mov rsi, r13
        call peek
        mov r15, rax ; next

        cmp r15, 0                                ; if next is null
        je parse_multiplicative_expression_return ; return

        mov rdi, r15
        call is_multiplicative
        cmp rax, 0                                ; if next is not multiplicative
        je parse_multiplicative_expression_return ; return

        mov rdi, r12
        mov rsi, r13
        call advance
        mov r15, rax ; op
        cmp r15, 0                              ; if op is null
        je parse_multiplicative_expression_fail ; fail

        mov rdi, r12
        mov rsi, r13
        mov rdx, r14
        add rdx, SIZEOF_EXPR
        call parse_primary_expression
        cmp rax, 0                              ; new expr is null
        je parse_multiplicative_expression_fail ; fail

        mov rdx, rax
        add rdx, SIZEOF_EXPR        ; new expr
        mov r8, [r15 + TOKEN_TYPE]
        mov [rdx + EXPR_TYPE], r8
        mov [rdx + EXPR_LEFT], r14  ; expr
        mov [rdx + EXPR_RIGHT], rax ; right

        mov r14, rdx ; expr = new expr

        jmp parse_multiplicative_expression_loop


    parse_multiplicative_expression_fail:
    mov rax, 0                              ; null
    jmp parse_multiplicative_expression_end
    parse_multiplicative_expression_return:
    mov rax, r14 ; ptr expr
    parse_multiplicative_expression_end:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

parse_primary_expression: ; (rdi: ptr ptr tokens, rsi: ptr len tokens, rdx: ptr expr) -> (rax: null|ptr expr)
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi ; ptr ptr tokens
    mov r13, rsi ; ptr len tokens
    mov r14, rdx ; ptr expr
    mov r15, 0   ; token|ptr expr

    mov rdi, r12
    mov rsi, r13
    call advance
    mov r15, rax                     ; token
    cmp r15, 0                       ; if token is null
    je parse_primary_expression_fail ; fail
    
    cmp qword [r15 + TOKEN_TYPE], TOKEN_TYPE_LEFT_PAREN
    je parse_primary_expression_left_paren

    cmp qword [r15 + TOKEN_TYPE], TOKEN_TYPE_NUMBER
    je parse_primary_expression_number

    jmp parse_primary_expression_fail

    parse_primary_expression_left_paren:
        mov rdi, r12          ; ptr ptr tokens
        mov rsi, r13          ; ptr len tokens
        mov rdx, r14          ; ptr expr
        call parse_expression
        mov r14, rax

        cmp r14, 0                       ; if parsing of child failed
        je parse_primary_expression_fail ; fail

        mov rdi, r12
        mov rsi, r13
        call advance
        mov r15, rax                     ; closing
        cmp r15, 0                       ; if closing is null
        je parse_primary_expression_fail ; fail

        cmp qword [r15 + TOKEN_TYPE], TOKEN_TYPE_RIGHT_PAREN
        jne parse_primary_expression_fail

        mov rax, r14
        add rax, SIZEOF_EXPR ; new
        mov qword [rax + EXPR_TYPE], EXPR_TYPE_GROUP
        mov [rax + EXPR_LEFT], r14             ; child
        jmp parse_primary_expression_return    ; return
        
    parse_primary_expression_number:
        mov rax, r14
        mov qword [rax + EXPR_TYPE], EXPR_TYPE_NUMBER
        mov r8, [r15 + TOKEN_NUMBER]
        mov [rax + EXPR_NUMBER], r8
        jmp parse_primary_expression_return

    parse_primary_expression_fail:
    mov rax, 0                             ; null
    jmp parse_primary_expression_end

    parse_primary_expression_return:
    parse_primary_expression_end:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

is_additive: ; (rdi: ptr expr) -> (rax: 0|1)
    mov rax, 1

    cmp qword [rdi + TOKEN_TYPE], TOKEN_TYPE_PLUS
    je return
    cmp qword [rdi + TOKEN_TYPE], TOKEN_TYPE_MINUS
    je return

    mov rax, 0
    ret

is_multiplicative: ; (rdi: ptr expr) -> (rax: 0|1)
    mov rax, 1

    cmp qword [rdi + TOKEN_TYPE], TOKEN_TYPE_STAR
    je return
    cmp qword [rdi + TOKEN_TYPE], TOKEN_TYPE_SLASH
    je return

    mov rax, 0
    ret

parse: ; (rdi: ptr tokens, rsi: len tokens, rdx: ptr expr) -> (rax: ptr node)
    push r12 ; ptr tokens
    push r13 ; len tokens
    push r14 ; i
    push r15 ; ptr expr

    mov r12, rdi ; ptr tokens
    mov r13, rsi ; len tokens
    mov r14, 0
    mov r15, rdx
    
    push r12
    push r13
    mov rdi, rsp
    add rdi, 8
    mov rsi, rsp
    mov rdx, r15
    call parse_expression
    pop r13
    pop r12

    parse_done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

evaluate: ; (rdi: ptr expr) -> (rax: n)
    cmp qword [rdi + EXPR_TYPE], EXPR_TYPE_GROUP
    je evaluate_group
    cmp qword [rdi + EXPR_TYPE], EXPR_TYPE_NUMBER
    je evaluate_number

    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_PLUS
    mov rsi, add64
    je evaluate_binary
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_MINUS
    mov rsi, sub64
    je evaluate_binary
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_STAR
    mov rsi, mul64
    je evaluate_binary
    cmp qword [rdi + EXPR_TYPE], TOKEN_TYPE_SLASH
    mov rsi, idiv64
    je evaluate_binary
    ret
    evaluate_group:
        mov rdi, [rdi + EXPR_LEFT]
        jmp evaluate
    evaluate_number:
        mov rax, [rdi + EXPR_NUMBER]
        ret
    evaluate_binary: ; (rdi: ptr expr, rsi: (rdi: n, rsi: n) -> (rax: n)) -> (rax: n)
        push r12
        push rsi
        mov r12, rdi
        mov rdi, [r12 + EXPR_LEFT]
        call evaluate
        push rax
        mov rdi, [r12 + EXPR_RIGHT]
        call evaluate
        pop rdi
        mov rsi, rax
        pop rdx
        call rdx
        pop r12
        ret

add64: ; (rdi: n, rsi: n) -> (rax: n)
    add rdi, rsi
    mov rax, rdi
    ret
sub64: ; (rdi: n, rsi: n) -> (rax: n)
    sub rdi, rsi
    mov rax, rdi
    ret
mul64: ; (rdi: n, rsi: n) -> (rax: n)
    imul rdi, rsi
    mov rax, rdi
    ret

write_indent: ; (rdi: fd)
    push r12
    mov r12, rdi

    mov rdi, r12
    mov rsi, ASCII_SPACE
    call write_char

    mov rdi, r12
    mov rsi, ASCII_SPACE
    call write_char

    mov rdi, r12
    mov rsi, ASCII_SPACE
    call write_char

    mov rdi, r12
    mov rsi, ASCII_SPACE
    call write_char

    pop r12
    ret


print_operations: ; (rdi: ptr operations) -> ()
    push r12
    push r13
    push r14
    mov r13, rdi ; ptr operations
    mov r12, 0   ; i
    
    mov rdi, AVAILABLE_OPERATIONS
    mov rsi, AVAILABLE_OPERATIONS_LEN
    call write_stdout
    call write_newline_stdout
    print_operations_loop:
        cmp r12, [r13]
        je print_operations_end

        mov rdi, STDOUT
        call write_indent


        mov rdi, ASCII_LEFT_BRACKET
        call write_char_stdout
        mov rdi, r12
        call write_u64_stdout
        mov rdi, ASCII_RIGHT_BRACKET
        call write_char_stdout

        mov rdi, ASCII_SPACE
        call write_char_stdout

        mov r14, r12
        imul r14, SIZEOF_OPERATION
        add r14, 8
        add r14, r13
 
        mov rdi, [r14]
        mov rsi, [r14 + 8]
        call write_stdout
        call write_newline_stdout

        add r12, 1
        jmp print_operations_loop
    print_operations_end:
    pop r14
    pop r13
    pop r12
    ret

choose_operation: ; (rdi: ptr calculator) -> (rax: ptr operation)
    push r12
    push r13
    push r14
    push r15
    enter 32
    mov r12, rsp
    mov r14, rdi

    choose_operation_read:
    mov rdi, r12
    mov rsi, 32
    call read_stdin
    mov r13, rax
    
    mov rdi, r12
    mov rsi, r13
    mov dl, ASCII_NEWLINE
    call str_trim_end
    call parse_u64
    mov r15, rax

    cmp r15, [r14]
    jge choose_operation_outofbounds
    jmp choose_operation_take

    choose_operation_outofbounds:
    mov rdi, INDEX_OUT_OF_BOUNDS
    mov rsi, INDEX_OUT_OF_BOUNDS_LEN
    call write_stdout
    mov rdi, ASCII_COLON
    call write_char_stdout
    mov rdi, ASCII_SPACE
    call write_char_stdout
    mov rdi, r15
    call write_u64_stdout

    mov rdi, ASCII_COMMA
    call write_char_stdout
    mov rdi, ASCII_SPACE
    call write_char_stdout
    mov rdi, TRY_AGAIN
    mov rsi, TRY_AGAIN_LEN
    call write_stdout
    call write_newline_stdout

    jmp choose_operation_read

    choose_operation_take:
    add r14, 8
    imul r15, SIZEOF_OPERATION
    add r15, r14
    mov rax, r15

    leave
    pop r15
    pop r14
    pop r13
    pop r12
    ret

print_chosen_operation: ; (rdi: ptr operation) -> ()
    push r12
    mov r12, rdi

    mov rdi, CHOSE_OPERATION
    mov rsi, CHOSE_OPERATION_LEN
    call write_stdout
    mov rdi, ASCII_COLON
    call write_char_stdout
    mov rdi, ASCII_SPACE
    call write_char_stdout
    
    mov rdi, [r12]
    mov rsi, [r12+8]
    call write_stdout

    call write_newline_stdout

    pop r12
    ret

run_calculator: ; (rdi: ptr calculator) -> ()
    push r12     ; ptr calculator
    push r13     ; ptr operation
    mov r12, rdi

    mov rdi, r12
    call print_operations

    mov rdi, r12
    call choose_operation
    mov r13, rax

    mov rdi, r13
    call print_chosen_operation

    call [r13 + 16] ; function pointer in Operation struct

    pop r13
    pop r12
    ret

main: ; (rdi: argc, rsi: argv) -> (rax: exit code)
    push r12
    push r13
    push r14
    mov r12, rdi ; argc
    mov r13, rsi ; argv
    
    mov rdi, r12    ; argc
    mov rsi, r13    ; argv
    call print_args
    
    sub rsp, CALCULATOR_SIZE
    mov r14, rsp
    mov rdi, r14
    call init_calculator

    mov rdi, r14
    call run_calculator
    
    mov rax, 0
    add rsp, CALCULATOR_SIZE
    pop r14
    pop r13
    pop r12
    ret

_start:
    pop rdi
    mov rsi, rsp
    call main
    mov rax, SYSCALL_EXIT
    mov rdi, 0            ; exit code
    syscall

    ; xor ebp, ebp                ; clear stack frame pointer
    ; mov r9, rdx                 ; 6. rtld_fini, is probably null
    ; pop rsi                     ; 2. argument argc
    ; mov rdx, rsp                ; 3. argument argv
    ; and rsp, 0xfffffffffffffff0 ; align stack
    ; push rax                    ; 7. argument stack end
    ; xor r8, r8                  ; 5. fini function = null
    ; xor rcx, rcx                ; 4. init funnction = null
    ; mov rdi, main               ; 1. main function
    ; push 0                      ; return address = null
    ; call __libc_start_main

section .data
PARSING_FAILED db "Parsing failed: ", 0
PARSING_FAILED_LEN equ $-PARSING_FAILED-1
AVAILABLE_OPERATIONS db "Available Operations:", 0
AVAILABLE_OPERATIONS_LEN equ $-AVAILABLE_OPERATIONS-1
ADDITION_NAME db "Addition", 0
ADDITION_NAME_LEN equ $-ADDITION_NAME-1
SUBTRACTION_NAME db "Subtraction", 0
SUBTRACTION_NAME_LEN equ $-SUBTRACTION_NAME-1
MULTIPLICATION_NAME db "Multiplication", 0
MULTIPLICATION_NAME_LEN equ $-MULTIPLICATION_NAME-1
DIVISION_NAME db "Division", 0
DIVISION_NAME_LEN equ $-DIVISION_NAME-1
SQUARE_NAME db "Square", 0
SQUARE_NAME_LEN equ $-SQUARE_NAME-1
STRING_MODE_NAME db "String Mode", 0
STRING_MODE_NAME_LEN equ $-STRING_MODE_NAME-1
INDEX_OUT_OF_BOUNDS db "Index out of bounds", 0
INDEX_OUT_OF_BOUNDS_LEN equ $-INDEX_OUT_OF_BOUNDS-1
TRY_AGAIN db "Try again!", 0
TRY_AGAIN_LEN equ $-TRY_AGAIN-1
CHOSE_OPERATION db "Chose operation", 0
CHOSE_OPERATION_LEN equ $-CHOSE_OPERATION-1
NUMBER_ONE db "Number 1", 0
NUMBER_ONE_LEN equ $-NUMBER_ONE-1
NUMBER_TWO db "Number 2", 0
NUMBER_TWO_LEN equ $-NUMBER_TWO-1
HEAP_ARRAY_INDEX_OUT_OF_BOUNDS db "heap_array index out of bounds!", 0
HEAP_ARRAY_INDEX_OUT_OF_BOUNDS_LEN equ $-HEAP_ARRAY_INDEX_OUT_OF_BOUNDS-1
HEAP_ARRAY_POP_EMPTY db "heap_array index out of bounds!", 0
HEAP_ARRAY_POP_EMPTY_LEN equ $-HEAP_ARRAY_POP_EMPTY-1
TOKEN_TYPE_NUMBER_STR db "TOKEN_TYPE_NUMBER", 0
TOKEN_TYPE_NUMBER_STR_LEN equ $-TOKEN_TYPE_NUMBER_STR-1
TOKEN_TYPE_LEFT_PAREN_STR db "TOKEN_TYPE_LEFT_PAREN", 0
TOKEN_TYPE_LEFT_PAREN_STR_LEN equ $-TOKEN_TYPE_LEFT_PAREN_STR-1
TOKEN_TYPE_RIGHT_PAREN_STR db "TOKEN_TYPE_RIGHT_PAREN", 0
TOKEN_TYPE_RIGHT_PAREN_STR_LEN equ $-TOKEN_TYPE_RIGHT_PAREN_STR-1
TOKEN_TYPE_PLUS_STR db "TOKEN_TYPE_PLUS", 0
TOKEN_TYPE_PLUS_STR_LEN equ $-TOKEN_TYPE_PLUS_STR-1
TOKEN_TYPE_MINUS_STR db "TOKEN_TYPE_MINUS", 0
TOKEN_TYPE_MINUS_STR_LEN equ $-TOKEN_TYPE_MINUS_STR-1
TOKEN_TYPE_STAR_STR db "TOKEN_TYPE_STAR", 0
TOKEN_TYPE_STAR_STR_LEN equ $-TOKEN_TYPE_STAR_STR-1
TOKEN_TYPE_SLASH_STR db "TOKEN_TYPE_SLASH", 0
TOKEN_TYPE_SLASH_STR_LEN equ $-TOKEN_TYPE_SLASH_STR-1
