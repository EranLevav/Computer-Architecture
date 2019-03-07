;;; Programmers: Natanel Mizrahi & Eran Levav, 2018
;;
; A polynomial in this program is represented by an array of consequtive coefficients, 
; e.g. (a0+ b0*i) + (a1+b1*i) + (an+bn*i) will be respresented as:
; |a0|b0| a1|b1|...|  an|bn|
;;
section .data
; scanf formats
    scanf_epsilon_format:   db "epsilon = %le ",10 , 0
    scanf_order_format:     db "order = %ld ",10, 0
    scanf_initial_format:   db "initial = %lf %lf ", 10, 0
    scanf_coeff_format:    db "coeff %ld = %lf %lf ",10, 0

; printf formats
    result_printf_format:   db "root = %.16le %.16le", 10, 0
    error_printf_format:    db "f(x)= c !=0. No roots exist.", 10, 0
    test:                   db "%ld konichiwa", 10, 0
    arr_format:             db "array [%ld] = %.16le ", 10, 0
; data holders
    epsilon:                dq 0
    order:                  dq 0
    counter:                dq 0
;counters
    coeff_idx:              dq 0
    order_counter           dq 0
    modulus                 dq 0
;complex_holders
    initial_real:           dq 0
    initial_img:            dq 0
    result_real:            dq 0
    result_img:             dq 0
    aux_real:               dq 0
    aux_img:                dq 0 

    OP1_real:               dq 0
    OP1_img:                dq 0
    OP2_real:               dq 0
    OP2_img:                dq 0
    OP3_real:               dq 0
    OP3_img:                dq 0

    currentZ_real:           dq 0  ; represents Zn+1
    currentZ_img:            dq 0
    lastZ_real:              dq 0  ; represents Zn
    lastZ_img:               dq 0   
;pointers
    poly_array_ptr:         dq 0
    deriv_array_ptr:        dq 0
    array_ptr:              dq 0
    aux_ptr:                dq 0

;; auxilliry macros ;;
%define img 8   ;; the offset of the imaginary coefficient from the pointer to the number is 8 bytes
%define real 0

;get_coeff_pointer(array_ptr, type, index)
; stores the coefficent of type (img | real) in index in the polynomial that array_ptr points to
;example: get_coeff_pointer(deriv_array_ptr, img, 5) stores the 5th imaginary coeff`s address of the derivative in [aux_ptr]
%macro get_coeff_pointer 3 ;((%1)array_ptr, (%2)type, (%3)index)
    mov r14, qword [%1]
    mov r13, %3
    sal r13, 4
    add r13, r14
    add r13, %2
    mov qword [aux_ptr], r13
%endmacro

%macro free_arrays 0
    mov rdi , [poly_array_ptr]
    call free
    mov rdi , [deriv_array_ptr]
    call free
%endmacro
; calls scanf with (%1::= format) (%2::= target variable address)
%macro read 2
    mov rdi , %1
    mov rsi, %2
    call scanf
%endmacro

%macro print 2
    mov rdi , %1
    mov rsi, %2
    call printf
%endmacro

%macro print3 2
    lea rdi , [arr_format]
    mov rsi, %1
    mov rbx, %2
    movsd xmm0 , qword [rbx]
    mov rax, 1
    call printf
%endmacro

; copies the data for %1 to %2
%macro copyComplexFromAToB 2
    push qword [%1_real]
    push qword [%1_img]
    pop qword [%2_img]
    pop qword [%2_real]
%endmacro

; purpose: malloc(2* (order+1) *sizeof(double));
; %1 - address of target array pointer 
; %2 - order of polynomial
%macro call_malloc 2
    mov rdi, %2
    inc rdi
    shl rdi, 4                                      ; multiply by 16 - array holds both imaginary and real coefficients
    call malloc                                     ; and sizeof(double)==8. total 16*(n+1) bytes required
    mov qword [%1], rax
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
section .text
    global main
    extern malloc, free, printf, scanf

main:
    push rbp
    mov rbp, rsp
    call init

    .check_order_0_case:
        cmp qword [order], 0    ; if(order > 0)
        jg .continue              ;   use newton raphson algorithm to get approximation for root
        get_coeff_pointer poly_array_ptr, real, 0
        mov r15, [aux_ptr]      ; r15= pointer to first coeff's real part
        lea r14, [r15 + 8]      ; r14= pointer to first coeff's imaginary part
        cmp qword [r15], 0      ; if (coeff0.real!=0 || coeff0.img !=0)
        jne .f_is_constant      ;   f(x) = c !=0
        cmp qword [r14], 0
        jne .f_is_constant
        .f_is_zero:             ; f(x)= 0 ==> print initial guess
            copyComplexFromAToB initial, currentZ
            jmp finish
        .f_is_constant:
            jmp error
    .continue:
        jmp main_loop

init:
        push rbp        
        mov rbp, rsp
    .read_data:
        read scanf_epsilon_format, epsilon
        read scanf_order_format, order
    .memory_alloc_for_polynomials:
        call_malloc poly_array_ptr, [order]
        mov rcx, [order]
        dec rcx
        call_malloc deriv_array_ptr, rcx            ;allocate memory for derivative array
    .read_coeffs:                                   ;reads a coefficient and stores it in the polynomial array data.
        mov rcx, [order]                            ; n+1 coefficients to read
        inc rcx
    finit
    .read_coeffs_loop:
        mov qword [counter], rcx                    ;backup counter
        mov rdi, scanf_coeff_format
        mov rsi, coeff_idx
        mov rdx, aux_real
        mov rcx, aux_img
        call scanf
        get_coeff_pointer poly_array_ptr, real, [coeff_idx]
        mov r14, [aux_real] 
        mov r15, [aux_ptr]
        mov qword [r15], r14
        mov r14, [aux_img]
        mov r15, qword [aux_ptr]
        mov qword [r15 + 8], r14

        .write_to_deriv_array:
            ;;;; deriv`s power is in R11
            mov r12, [deriv_array_ptr]
            mov rax, [coeff_idx]
            cmp rax, 0                               ; check if the index of the original polynomial is not 0
            je .skip                                 ; index 0 is not calculated for derivative
            fild qword [coeff_idx]
            fld qword [aux_real]
            fmul

            mov r11, [coeff_idx]
            dec r11
            get_coeff_pointer deriv_array_ptr, real, r11
            ;;aux_ptr now points to address of the next derivative coeff
            mov r15, [aux_ptr]
            fstp qword [r15]
            ;imaginary part
            fild qword [coeff_idx]  ;load int to FPU registers
            fld qword [aux_img]
            fmul
            fstp qword [r15 + 8]
    .skip:
        mov rcx, [counter] ;restore counter
        dec rcx
        jnz .read_coeffs_loop
    .read_initial_guess:
        mov rdi , scanf_initial_format
        lea rsi , [initial_real]
        lea rdx , [initial_img]
        xor rax, rax
        call scanf
    .return:
        mov rsp, rbp
        pop rbp
        ret 

;;;;;;;;;;;;;ARITHMETIC FUNCTIONS;;;;;;;;;;;;
;@return:   void
; loads arguments to OP1 and OP2 for arithmetic functions
%macro load_OPs 2
    copyComplexFromAToB %1, OP1
    copyComplexFromAToB %2, OP2
%endmacro

;LEGEND:
;qword [OP1_real] -  real part of OP1
;qword [OP1_img] -  imaginary part of OP1
;qword [OP2_real] -  real part of OP2
;qword [OP2_img] -  imaginary part of OP2

addComplex:
    push rbp        
    mov rbp, rsp
    fld qword [OP1_real]                      ; st0 <- qword [OP1_real]
    fld qword [OP2_real]                      ; st1 <- qword [OP2_real]
    fadd                                      ; st0 = ( real)num1 + ( real)num2
    fstp qword [result_real]                  ; store st(0) into [result_real] (=.x field)
    fld qword [OP1_img]                       ; st0 <- qword [OP1_img]
    fld qword [OP2_img]                       ; st1 <- qword [OP2_img]
    fadd                                      ; st0 = (img)num1 + (img)num2
    fstp qword [result_img]                   ; store st(0) into [result_img] (=.y field)
    mov rsp, rbp
    pop rbp                         
    ret


subComplex:
    push rbp        
    mov rbp, rsp
    fld qword [OP1_real]                    ; st0 <- qword [OP1_real]
    fld qword [OP2_real]                    ; st1 <- qword [OP2_real]
    fsub                                    ; st0 = ( real)num1 - ( real)num2 // TODO MINUS? 5-7 ?
    fstp qword [result_real]                ; store st(0) into [result_real] (=.x real field)
    finit                                   ; initialize the x87 subsystem for the  imaginary addition
    fld qword [OP1_img]                     ; st0 <- qword [OP1_img]
    fld qword [OP2_img]                     ; st1 <- qword [OP2_img]
    fsub                                    ; st0 = (img)num1 + (img)num2
    fstp qword [result_img]                 ; store st(0) into [result_img] (=.y imaginary field)

    mov rsp, rbp
    pop rbp                         
    ret

;(a+bi)*(c+di) = (ac-bd) + (ad + bc)i
mulComplex:
    push rbp        
    mov rbp, rsp
    fld qword [OP1_real]                    ; st0 <- qword [OP1_real]
    fld qword [OP2_real]                    ; st1 <- qword [OP2_real]
    fmul                                    ; st0 = (real)num1 * (real)num2 // TODO MINUS?
    fld qword [OP1_img]                     ; st1 <- qword [OP1_img]
    fld qword [OP2_img]                     ; st2 <- qword [OP2_img]
    fmul                                    ; st1 = (imaginary)num1 * (imaginary)num2 // TODO MINUS?
    fsub
    fstp qword [result_real]                ; store st(0) into [result_real] (=>.x real field =(ac-bd))
    ; finit                                 ; initialize the x87 subsystem for the  imaginary addition
    fld qword [OP1_real]                    ; st0 <- qword [OP1_real]
    fld qword [OP2_img]                     ; st1 <- qword [OP2_img]
    fmul                                    ; st0 = (real)num1 * (imaginary)num2 // TODO MINUS?
    fld qword [OP1_img]                     ; st1 <- qword [OP1_img]
    fld qword [OP2_real]                    ; st2 <- qword [OP2_real]
    fmul                                    ; st1 = (imaginary)num1 * (imaginary)num2 // TODO MINUS?
    fadd
    fstp qword [result_img]                 ; store st(1) into [result_img] (=.y imaginary field)

    mov rsp, rbp
    pop rbp                         
    ret

;xmm4 - (cc+dd)
;(a+bi)/(c+di) = (ac+bd)/(cc+dd) + (bc-ad)/(cc+dd)i  
divComplex:
    push rbp        
    mov rbp, rsp
;(cc+dd)
    fld qword [OP2_real]                    ; st0 <- qword [OP2_real]
    fld qword [OP2_real]                    ; copy st(0) into st(1)
    fmul                                    ; st0 <- c*c
    fld qword [OP2_img]                     ; st1 <- qword [OP2_img]
    fld qword [OP2_img]                     ; copy st(1) into st(2)
    fmul                                    ; st1 <- d*d
    fadd                                    ; st0 <- cc+dd
    fstp qword [OP3_real]                   ; store st(0) into [OP3_real] 
;(ac+bd)
    fld qword [OP1_real]                    ; st0 <- qword [OP1_real]
    fld qword [OP2_real]                    ; st1 <- qword [OP2_real]
    fmul                                    ; st0 = (real)num1 * (real)num2 // TODO MINUS?
    fld qword [OP1_img]                     ; st1 <- qword [OP1_img]
    fld qword [OP2_img]                     ; st2 <- qword [OP2_img]
    fmul                                    ; st1 = (imaginary)num1 * (imaginary)num2 // TODO MINUS?
    fadd                                    ; st0 = ac+bd                  
    fld qword [OP3_real]                    ; st0 <- cc+dd
    fdiv                                    ; (ac+bd)/(cc+dd)
    fstp qword [result_real]                ; store st(0) into [result_real] (=>.x real field)
;(bc-ad)
    fld qword [OP1_img]                     ; st0 <- qword [OP1_real]
    fld qword [OP2_real]                    ; st1 <- qword [OP2_img]
    fmul                                    ; st0 = (real)num1 * (imaginary)num2 // TODO MINUS?
    fld qword [OP1_real]                    ; st1 <- qword [OP1_img]
    fld qword [OP2_img]                     ; st2 <- qword [OP2_real]
    fmul                                    ; st1 = (imaginary)num1 * (imaginary)num2 // TODO MINUS?
    fsub                                    ; (bc-ad)
    fld qword [OP3_real]                    ; st1 <- cc+dd
    fdiv                                    ; (ac+bd)/(cc+dd)
    fstp qword [result_img]                 ; store st(0) into [result_img] (=.y imaginary field)
    mov rsp, rbp
    pop rbp                         
    ret




;qword [OP1_real]- a
;qword [OP1_img]- b
modulusComplex:
    push rbp        
    mov rbp, rsp
    fld qword [OP1_real]                     ; st0 <- qword [OP1_real]
    fld qword [OP1_real]
    fmul
    fld qword [OP1_img]                      ; st1 <- qword [OP2_real]
    fld qword [OP1_img]                      ; st1 <- qword [OP2_real]
    fmul                                     ; st0 = ( real)num1 + ( real)num2
    fadd
    fsqrt
    fstp qword [modulus]
    mov rsp, rbp
    pop rbp                         
    ret

; OP1 * OP2 + OP3
complexFMA:
    push rbp        
    mov rbp, rsp
    finit
    call mulComplex
    load_OPs result, OP3
    call addComplex
    mov rsp, rbp
    pop rbp                         
    ret


; order_counter
; %1- poly coeff array pointer
; %2- order
%macro set_eval_poly_args 2
    mov r15, %1
    mov qword [array_ptr], r15
    mov r15, %2
    mov qword [order_counter], r15
%endmacro


; computes f(Z)
;preconditions: x is in lastZ
eval_poly:
    push rbp        
    mov rbp, rsp
.init:
    mov qword [result_real], 0    ; reset the result
    mov qword [result_img], 0
    get_coeff_pointer array_ptr, real, qword [order_counter]
    mov r14, [aux_ptr]                  ; pointer to next real coeff
    lea r15, [r14 + 8]                  ; pointer to next imaginary coeff
    .loop:
        push qword [r14]
        push qword [r15]
        pop qword [OP3_img]
        pop qword [OP3_real]
        load_OPs result, lastZ
       
        call complexFMA  ; at this point: OP1= result, OP2= x, OP3= coeff[i]
        sub r14, 16 
        sub r15, 16
        dec qword [order_counter]
        cmp qword [order_counter], 0
        jge .loop
.done:
    mov rsp, rbp
    pop rbp                         
    ret

newton_raphson:
    push rbp        
    mov rbp, rsp
    set_eval_poly_args [poly_array_ptr], [order]
    call eval_poly                                      ; f(Z) is in result at this point
    copyComplexFromAToB result, currentZ                 ; f(Z) is in currentZ
    mov r15, [order]
    dec r15
    set_eval_poly_args [deriv_array_ptr], [order]
    dec qword [order_counter]
    call eval_poly                                      ; f'(Z) is in result (for example f'(3+i))
    load_OPs currentZ, result                            ; compute f(Z)/f'(Z) '
    call divComplex
    load_OPs lastZ, result                               ; call Zn-result i.e Zn- f(Z)/f'(Z) '
    call subComplex
    copyComplexFromAToB result, currentZ                 ; move result to currentZ (Zn+1)
    mov rsp, rbp
    pop rbp                         
    ret

;; lastZ represents Zn. currentZ (at the end of the newton_raphson algorithm) represents Zn+1
main_loop:
    .init:
        copyComplexFromAToB initial, currentZ
    .apply_algorithm:
        copyComplexFromAToB currentZ, lastZ
        call newton_raphson
    .check_result:
        set_eval_poly_args [poly_array_ptr], [order]
        copyComplexFromAToB currentZ, lastZ
        call eval_poly
        load_OPs result, result
        call modulusComplex                                 ;compute |f(Zn+1)|
        fld qword [modulus]
        fld qword [epsilon]
        fcomip                                              ; check if |f(Zn+1)|< epsilon
        jl finish
        jnb finish
        jmp .apply_algorithm                                ; if the currentZ guess isn`t sufficiantly close to epsilon, continue


finish:
    mov rdi , result_printf_format
    movsd xmm0, qword [currentZ_real]
    movsd xmm1, qword [currentZ_img]
    mov rax, 2
    call printf
    free_arrays
    mov rsp, rbp
    pop rbp
    ret

error:
    mov rdi, error_printf_format
    call printf
    free_arrays
    mov rsp, rbp
    pop rbp
    ret
