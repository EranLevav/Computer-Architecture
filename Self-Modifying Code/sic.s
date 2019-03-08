;;; Programmers: Natanel Mizrahi & Eran Levav, 2018
section .data
	%define MAX_PHYSICAL_MEMORY 4096
	%define sizeof_int 8
	
; scanf & printf formats
	printf_int_format:  db "%ld ", 0
	scanf_int_format:   db "%ld", 0
    new_line:			db 10, 0

;; AUXILLIRY MACROS ;;
; calls scanf with (%1::= format) (%2::= target variable address)
%macro read 1
    mov rdi , scanf_int_format
    mov rsi, %1
    call scanf
%endmacro

;; print the number in %1
%macro print 1
    mov rdi , printf_int_format
    mov rsi , %1
    call printf
%endmacro

;; print \n
%macro newline 0
    mov rdi , new_line
    call printf
%endmacro

%macro call_malloc 1
    lea rdi, [sizeof_int* %1]
    call malloc
%endmacro

; %2 <-- pointer to M[%1]
%macro get_mi_address 2
    lea rdi, [%1]
    lea rdi, [sizeof_int * rdi]
    add rdi, qword [memory_ptr]
    mov %2, rdi 
%endmacro

; %2 <-- M[%1]
%macro get_mi 2
    get_mi_address %1, %2
    mov %2, [%2]
%endmacro

; A = M[i] ; B = M[i + 1]; C = M[i + 2]
%macro load_ops 0
	get_mi r15, rdx
	mov qword [A], rdx		; A = M[i]
	get_mi r15 + 1, rdx
	mov qword [B], rdx		; B = M[i + 1]
	get_mi r15 + 2, rdx		; C = M[i + 2]
	mov qword [C], rdx
%endmacro

section .bss
	next_num:	resq 1
	memory_ptr: resq 1
	word_count: resq 1
	A: 			resq 1
	B: 			resq 1
	C: 			resq 1

section .text
    global main
    extern printf, scanf, malloc, free, exit

; using r15 as counter since printing ruins rcx
main:
	enter 0,0
.malloc:
	call_malloc MAX_PHYSICAL_MEMORY
	mov qword [memory_ptr], rax				; *memory_ptr = memory array ptr
	xor r15, r15							; reset counter
.scan:
	read next_num
	cmp rax, 1 								; while(scanf(...)== 1) //not EOF
	jne .done_scanning
	lea r13 , [r15 * sizeof_int]
	add r13, qword [memory_ptr]				; r13 <-- pointer to M[i]
	mov r14, qword [next_num]				; M[i] = next_num
	mov qword [r13], r14 					
	inc r15									; i++
	jmp .scan

.done_scanning:
	mov qword [word_count], r15				; save word count

.init:
	xor r15, r15							; r15 = i = 0

.check_program_end:
	load_ops
	cmp qword[A], 0 						;check if (M[A]==0)
	jne .continue
	cmp qword[B], 0 						;check if (M[B]==0)
	jne .continue
	cmp qword[C], 0 						;check if (M[C]==0)
	jne .continue
	jmp .print
.continue:
	mov rax, qword [A]
	get_mi_address rax, r10 			; r10 <- pointer to M[M[i]]
	mov rax, [r10]						; rax <- M[M[i]]
	mov rbx, qword [B]
	get_mi rbx, rbx						; rbx <- M[M[i + 1]]
	sub rax, rbx						; rax <- M[M[i]] - M[M[i + 1]]
	mov qword [r10], rax				; M[M[i]] -= M[M[i + 1]]
	cmp rax, 0							; if ((M[M[i]] -= M[M[i + 1]]) < 0)
	jge .is_greater
.is_less:
	get_mi r15+2, r15 					; 	i = M[i+2]
	jmp .next_iteration
.is_greater:							; else
	add r15, 3							;	i += 3
.next_iteration:
	jmp .check_program_end
.print:									; print the memory
	xor r15, r15
	.loop:
		cmp r15, qword[word_count]
		jge .finish
		get_mi r15, r14
		print r14
		inc r15
		jmp .loop
.finish:
	newline
	mov rdi, qword [memory_ptr]
	call free
	leave
