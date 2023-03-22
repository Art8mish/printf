; nasm -f elf64 -l 1-nasm.lst 1-nasm.s  ;  ld -s -o 1-nasm 1-nasm.o

section .text

global _start                  ; predefined entry point name for ld

;________________________
;Exit Program
;------------------------
;Entry:     None
;Exit:      None
;Expects:   None
;Destroys:  rax, rdi
;------------------------
%macro EXIT0 0
            nop
            mov rax, 0x3C      ; exit64 (rdi)
            xor rdi, rdi
            syscall
            nop
%endmacro

_start:     mov rax, 0x01      ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1         ; stdout
            mov rsi, Msg
            mov rdx, MsgLen    ; strlen (Msg)
            syscall

            mov rsi, Msg
            push 50
            push Str
            push rsi
            call Printf

            EXIT0

;_______________________________________
;printf
;=======================================
;Entry:     
;   In stack:
;           string ptr
;           1st arg if exist
;           2nd arg if exist
;           ...
;Exit:      Amount of printed args
;Expects:   es 
;Destroys:  rax, rbx, rcx, rdx, rsi, rdi
;=======================================

Printf:     push rbp                    ;prologue
            mov rbp, rsp                ;

            xor rax, rax                ;rax = printed args counter (returned val)
            mov rsi, [rbp + 16]         ;rsi = str ptr
            xor rdx, rdx                ;rdx = 0 (will be string len without specifiers)
            mov rbx, 16                 ;[rbp + rbx] = args

.StrLoop:   cmp byte [rsi + rdx], 0x0         ;0x0 = '\0' (EOS)
            je .ExitPrnt

            cmp byte [rsi + rdx], 0x25        ;0x25 = '%'
            jne .CmmnSymb

            push rax
            mov rax, 0x01               ;write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                  ;rdi = stdout
            syscall
            pop rax

            inc rdx
            add rsi, rdx                ;[rsi] = symb after '%'
            xor rdx, rdx

            cmp byte [rsi], 0x25        ;check for "%%"
            je .CmmnSymb

            mov byte dl, [rsi]          ;rdx = specifier byte (b c d o s x)
            inc rsi                     ;rsi++
            sub rdx, 0x62               ;'b' = 0x62

.Switch:    push rsi
            push rax

            add rbx, 8                  ;args[(rbx - 24) / 8]
            mov rax, [rbp + rbx]        ;rax = arg
            jmp [.SpcTbl + rdx * 8]     ;switch(rdx)

.PrintBin:  call PrintBin
            jmp .SwitchEnd

.PrintChar: mov byte [Symb], al
            mov rax, 0x01
            mov rsi, Symb
            mov rdi, 1
            mov rdx, 1
            syscall
            jmp .SwitchEnd

.PrintDec:  call PrintDec
            jmp .SwitchEnd

.PrintOct:  call PrintOct
            jmp .SwitchEnd

.PrintStr:  mov rsi, rax
            xor rdx, rdx
    .Strln: or byte [rax], 0x0
            jz .Print
            inc rdx
            inc rax
            jmp .Strln

.Print      mov rax, 0x01
            mov rdi, 1
            syscall
            jmp .SwitchEnd       
            
.PrintHex:  call PrintHex
            jmp .SwitchEnd


.ErrSpec:   pop rax                     ;return (-1)
            pop rsi                     ;
            pop rbp                     ;
            mov rax, -1                 ;
            ret                         

.SwitchEnd: pop rax
            pop rsi
;--------------         
            inc rax                     ;printed args counter++
            xor rdx, rdx
            jmp .StrLoop

.CmmnSymb: inc rdx
            jmp .StrLoop

.ExitPrnt:  push rax                    ;
            mov rax, 0x01               ;write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                  ;rdi = stdout           
            syscall
            pop rax

            pop rbp
            ret



section     .rodata

.SpcTbl:    dq .PrintBin                 ;[0] -----> %b
            dq .PrintChar                ;[1] -----> %c
            dq .PrintDec                 ;[2] -----> %d
            times 10 dq .ErrSpec         ;[3-12] --> err
            dq .PrintOct                 ;[13] ----> %o
            times 3 dq .ErrSpec          ;[14-16] -> err
            dq .PrintStr                 ;[17] ----> %s
            times 4 dq .ErrSpec          ;[18-21] -> err
            dq .PrintHex                 ;[22] ----> %x

section     .data


Msg:        db "Vlad %s LaZar' %d", 0x0a, 0x0
Str:        db "Huesos", 0x0
MsgLen      equ $ - Msg

Symb:       times 64 db 0x0             ;array for printing nums
PrintFlag:  db 0

section     .text

;_______________________________________
;Print Bin
;=======================================
;Entry:     eax = num
;Exit:      None
;Expects:   None
;Destroys:  rax, rcx, rdx, rdi, rsi
;=======================================
PrintBin:   push rbx

            mov rdi, 1                  ;rdi = stdout
            mov rsi, Symb               ;[rsi] = symb for printing
            mov byte [PrintFlag], 0

            mov rcx, 64                 ;64 bit in rax
            xor rbx, rbx
            inc rbx
            shl rbx, 63                 ;1000000000000000b

.Next:      mov rdx, 0x30               ;put '0' ASCII in rbx
            test rax, rbx               ;check bit, put zf
            jz .Print                   ;if (zf == 1) jmp @@Print

            inc rdx                     ;'1' ASCII in rbx
            mov byte [PrintFlag], 1

.Print:     and byte [PrintFlag], 1
            jz .LoopEnd
            mov byte [Symb], dl         ;'0'/'1' in Symb
            push rax
            push rcx
            mov rax, 0x01               ;write64 (rdi, rsi, rdx)
            mov rdx, 1                  ;for printing 1 symb 
            syscall
            pop rcx
            pop rax

.LoopEnd:   shr rbx, 1                  ;rbx>>1
            loop .Next

.End:       pop rbx
            ret


;_______________________________________
;Print Hex
;=======================================
;Entry:     rax = num
;Exit:      None
;Expects:   None
;Destroys:  rax, rcx, rdx, rdi, rsi
;=======================================
PrintHex:   push rbx

            mov rdi, 1                  ;rdi = stdout
            mov rsi, Symb               ;[rsi] = symb for printing
            mov byte [PrintFlag], 0

            mov rcx, 16                 ;64 bit in rax (16 hex nums)
            xor rbx, rbx
            inc rbx
            shl rbx, 63                 ;1000000000000000b

.Next:      push rcx
            mov rcx, 4                  ;4 bit = 1 hex symb

            mov rdx, 0x30               ;put '0' ASCII in rbx
.HexSymb:   test rax, rbx               ;check bit, put zf
            jz .NullBit
        
            push rax                    ;
            mov rax, 1                  ;
            shl rax, cl                 ;
            shr rax, 1                  ;
            add rdx, rax                ;rdx += 2^(rcx - 1)
            pop rax

.NullBit:   shr rbx, 1                  ;rbx>>1
            loop .HexSymb
            pop rcx

            cmp byte [PrintFlag], 1
            je .Print

            cmp rdx, 0x30
            je .LoopEnd
            mov byte [PrintFlag], 1

.Print:     cmp rdx, 3ah                ;3ah = ASCII code of ':' after '9'
            jc .NumHex

            add rdx, 7

.NumHex:    mov byte [Symb], dl         ;'0'/'1' in Symb
            push rax
            push rcx
            mov rax, 0x01               ;write64 (rdi, rsi, rdx)
            mov rdx, 1                  ;for printing 1 symb 
            syscall
            pop rcx
            pop rax

.LoopEnd:   loop .Next

.End:       pop rbx
            ret

;_______________________________________
;Print Dec
;=======================================
;Entry:     rax = num
;Exit:      None
;Expects:   None
;Destroys:  rax, rcx, rdx, rdi, rsi
;=======================================
PrintDec:   push rbx

.Next:      mov rdi, 1                  ;rdi = stdout
            mov rsi, Symb               ;[rsi] = symb for printing
            mov rbx, 10                 ;will div by 10

            xor rcx, rcx
.DivIter:   cmp rax, 10                 ;if (rax < 10) cf = 1
            jc .Print                   ;

            push rax
            shr rax, 32
            mov rdx, rax
            pop rax                     ;edx:eax = num

            div ebx                     ;eax = edx:eax / 10, edx = edx:eax % 10
            push rdx
            inc rcx                     ;counter++
            jmp .DivIter

.Print:     add rax, 0x30           ;0x30 = '0'
            mov byte [Symb], al
            mov rax, 0x01               ;write64 (rdi, rsi, rdx)
            mov rdx, 1                  ;for printing 1 symb 
            push rcx
            syscall
            pop rcx

            cmp rcx, 0
            je .DecEnd

.Printl:    pop rax
            add rax, 0x30               ;0x30 = '0'
            mov byte [Symb], al
            mov rax, 0x01               ;write64 (rdi, rsi, rdx)
            push rcx
            syscall
            pop rcx
            loop .Printl

.DecEnd:    pop rbx
            ret

;_______________________________________
;Print Oct
;=======================================
;Entry:     rax = num
;Exit:      None
;Expects:   None
;Destroys:  rax, rcx, rdx, rdi, rsi
;=======================================
PrintOct:   push rbx

            mov rdi, 1                  ;rdi = stdout
            mov rsi, Symb               ;[rsi] = symb for printing
            mov byte [PrintFlag], 0

            mov rcx, 21                 ;64 bit in rax (21 hex nums)
            xor rbx, rbx
            inc rbx
            shl rbx, 63                 ;1000000000000000b

;first byte
            mov rdx, 0x31               ;put '1' ASCII in rdx
            test rax, rbx               ;check bit, put zf
            jz .LoopStart

            shr rbx, 1 
            jmp .Print

.LoopStart: shr rbx, 1 
.Next:      push rcx
            mov rcx, 3                  ;3 bit = 1 oct symb

            mov rdx, 0x30               ;put '0' ASCII in rdx
.OctSymb:   test rax, rbx               ;check bit, put zf
            jz .NullBit
        
            push rax                    ;
            mov rax, 1                  ;
            shl rax, cl                 ;
            shr rax, 1                  ;
            add rdx, rax                ;rdx += 2^(rcx - 1)
            pop rax

.NullBit:   shr rbx, 1                  ;rbx>>1
            loop .OctSymb
            pop rcx

            cmp byte [PrintFlag], 1
            je .Print

            cmp rdx, 0x30
            je .LoopEnd
            mov byte [PrintFlag], 1

.Print:     mov byte [Symb], dl         ;'0'/'1' in Symb
            push rax
            push rcx
            mov rax, 0x01               ;write64 (rdi, rsi, rdx)
            mov rdx, 1                  ;for printing 1 symb 
            syscall
            pop rcx
            pop rax

.LoopEnd:   loop .Next

.End:       pop rbx
            ret

