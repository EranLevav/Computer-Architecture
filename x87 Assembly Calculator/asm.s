section .data
	OP1_pointer: 			dq 0
	OP2_pointer: 			dq 0
	result_pointer:			dq 0
	aux_pointer:			dq 0
	factor_pointer:			dq 0

	div_format:				db "OP1: %s",10, "OP2: %s", 10, "RES: %s", 10, "factor: %s", 10, 	0
	printf_format2:			db "::[%ld] %s", 10, 0
	msg :					db "Here:", 0  
	msg2: 					db "state of OP1, OP2, result, factor:", 0
	comp :					db "is the comparator result", 0

section .text
	extern printf,bignum_destructor, bignum_copy_constructor
	extern push, pop, bignum_trim, bignum_constructor_by_size, printStack, addProcessor, bignum_abs_comparator
	global add, substract, multiply, divide
	global push_copy

;;; AUXILLIRY MACROS

%macro delete 1
	mov rdi, %1
	call bignum_destructor
%endmacro


%macro add_to_result 1
;@param(%1): pointer to bignum to be added to result
;@return: 	void
; adds the parameter to result

;	.backup:
		backup_registers
		mov r15, %1
		push qword [OP2_pointer]
		pop qword [aux_pointer]
;	.push_and_add:                    
		mov rdi, %1
		call push_copy
		mov rdi, [result_pointer] 
		call push
		call addProcessor
		call pop
		mov qword [result_pointer], rax
;	.restore:
		push qword [aux_pointer]
		pop qword [OP2_pointer]
		mov qword %1, r15
		restore_registers
%endmacro

%macro backup_registers 0
	push rax
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
%endmacro

%macro restore_registers 0
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	pop rax
%endmacro

%macro backup_all 0
	backup_registers
	push qword [OP1_pointer]
	push qword [OP2_pointer]
	push qword [result_pointer]
	push qword [factor_pointer]
%endmacro

%macro restore_all 0
	pop qword [factor_pointer]
	pop qword [result_pointer]
	pop qword [OP2_pointer]
	pop qword [OP1_pointer]
	restore_registers
%endmacro

;;printouts

%macro print_msg 2
	backup_registers
	mov rdx,%2
	mov rsi, %1
	mov rdi, printf_format2
	call printf
	restore_registers
%endmacro

%macro print_all 1
; prints OP1, OP2, result, factor
	backup_registers
	print_msg %1, msg2
	mov rdi, div_format
	mov rsi, [OP1_pointer]
	mov rsi, [rsi]
	mov rdx, [OP2_pointer]
	mov rdx, [rdx]
	mov rcx, [result_pointer]
	mov rcx, [rcx]
	mov r8, [factor_pointer]
	mov r8, [r8]
	call printf
	restore_registers
%endmacro

;;;METHODS

init:								
; init(OP_CODE)
; loads the registers with the data required
; for the operation corresponding to @param(OP_CODE)

; LEGEND:
; @param(OP_CODE)
;  1 => add
;  2 => multiply
;  3 => substract
;  4 => divide

	push rbp		
	mov rbp, rsp
	mov r14, rdi
	call load_operands				;
	mov	rdi, r14					; #compute the maximum digits required for the result:
	cmp rdi, 1						; switch(OP_CODE)
	je .add_or_mult					; case add:
	cmp rdi, 2						; 	resultDigits += 1
	je .add_or_mult					; case multiply:
	jne .sub_or_div					;	resultDigits += 1
	.add_or_mult:							; case substract || divide:
		add rdi, r10				;	resultDigits = maxN
		jmp .continue				;
	.sub_or_div:					;
		mov rdi, r10				;
	.continue:						; #Create a bignum for the result:	
	push r8
	call bignum_constructor_by_size ; bignum_constructor_by_size(resultDigits)
	pop r8
	mov qword [result_pointer], rax	; [result_pointer] = (bignum*)result
	mov r12, [rax]					; r12 = result -> digits
	mov r13, [rax+8]				; r13 = result -> number_of_digits
	dec r13							;
	dec r13							; set counters r10, r11, r13 be the last index of OP1[], OP2[], result[]
	dec r10
	dec r11
	xor rbx, rbx					;clear registers before operation
	xor rcx, rcx
	xor rdx, rdx
	mov rsp, rbp
	pop rbp
	ret

load_operands:
;Stores the data of the top 2 bignums (OP1, OP2) in the Stack
;creates a new bignum for the result and stores it`s data in the registers

; LEGEND:
; r8: 	OP1 -> digit[] array
; r9: 	OP2 -> digit[] array
; r10: 	OP1 -> number_of_digits
; r11: 	OP2 -> number_of_digits
; r12: 	result -> digit[] array
; r13: 	result -> number_of_digits
; [result_pointer]: 	result`s (bignum*) pointer

	push rbp		
	mov rbp, rsp 
	call pop 							;
	mov qword [OP1_pointer], rax		; OP1_pointer= pop()
	mov r8, [rax]						; 
	mov r10, [rax+8]					; r10 = OP1 -> number_of_digits
	dec r10								; ignore delimiter '\0'
	push r8
	call pop							;
	pop r8
	mov qword [OP2_pointer], rax		; OP2_pointer= pop()
	mov r9, [rax]						;
	mov r11, [rax+8]					; r11 = OP2 -> number_of_digits
	dec r11								; ignore delimiter '\0'
	mov rsp, rbp
	pop rbp
	ret

;---------------------------------------------
add:
; computes OP1 + OP2 and frees operands memory
	push rbp		
	mov rbp, rsp
	call add_helper 
	delete [OP1_pointer]
	delete [OP2_pointer]
	mov rsp, rbp
	pop rbp
	ret

add_helper:
; OP1 + OP2
; does not free operands memory
; al: OP1`s current LSB
; bl: OP2`s current LSB
; cl: carry

	push rbp		
	mov rbp, rsp
	mov rdi, 1							; init(ADD)
	call init							; load stack operands and result data to registers
	mov cl, 0							; carry = 0

	.loop:								; addition loop
		cmp r10, 0						; if(!OP1_remaining_digits)
		jl .handle_MSB_carry 			; 	exit loop
		mov al, [r8+r10]				; al = next char of OP1
		sub al, '0'						; convert char to int
		cmp r11, 0						; if (OP2_remaining_digits)
		jl .finished_smaller_num		;	{ignore OP2}
		mov bl, [r9+r11]				; bl = next char of OP2
		sub bl, '0'						; convert char to int
		add al, bl						; digitSum += bl 

		.finished_smaller_num:			;
			add al, cl					; digitSum += carry
			mov cl, 0					; carry = 0
			cmp al, 9					; if(digitSum <= 9)
			jna .no_carry				;
			mov cl, 1					; 	carry = 1
			sub al, 10					; 	digitSum -= 10  #actual digit value

			.no_carry:					;
				add al, '0'				; convert int to char
				mov byte [r12+r13], al 	; result -> nextDigit = al
				dec r10      			; OP1_remaining_digits--
				dec r11   				; OP2_remaining_digits--
				dec r13					; result_next_digit--
				jmp .loop				; GOTO loop

	.handle_MSB_carry:
		cmp cl, 0						; if(!carry)
		mov byte [r12], '0'				; 	no carry >> add leading zero
		je 	done						; else
		mov byte [r12], '1'				;	MSB_carry = 1
		jmp done

;---------------------------------------------
substract:
; computes OP1 + OP2 and frees operands memory
	push rbp		
	mov rbp, rsp
	call substract_helper
	delete [OP1_pointer]
	delete [OP2_pointer]
	mov rsp, rbp
	pop rbp
	ret

substract_helper:
; OP1 - OP2
; al: OP1`s current LSB
; bl: OP2`s current LSB
; cl: borrow

	push rbp		
	mov rbp, rsp
	mov rdi, 3							; init(SUBSTRACT)
	call init							; load stack operands data to registers
	mov cl, 0							; borrow = 0

	.loop:								; substraction loop
		cmp r10, 0						; if(!OP1_remaining_digits)
		;jl .check_msb					;   exit loop and check msb
		jl done				 			;   exit loop
		mov al, [r8+r10]		 		; al = next char of OP1
		sub al, '0'				  		; convert char to int
		cmp r11, 0			 			; if (!OP2_remaining_digits)
		jl .finished_smaller_num		;
		mov bl, [r9+r11]     			; bl = next char of OP2
		sub bl, '0'			 			; convert char to int
		cmp al, bl           			; check if we need to borrow
		jge .no_borrow1      			; if (OP1_digit < OP2_digit)
		sub al, bl			 			; 	 al -= bl
		add al, 10           			;   add borrow
		sub al, cl						;   al -= borrow
		mov cl, 1   	    	   	  	;   borrow = 1
		jmp .continue					;
										
		.no_borrow1:					;   else
			sub al, bl				    ; 	   al -= bl
										;
		.handle_borrow_OP1:				;
			cmp al, cl     		    	;     #check if we need to borrow
			jge .no_borrow2				;     if(al== 0 && borrow == 1)

			add al, 10  	       		; 			add borrow
			sub al, cl					; 			al -= borrow	
			mov cl, 1					; 			borrow = 1
			jmp .continue				; 
										;
		.no_borrow2:					; 	  else
			sub al, cl					; 			al-= borrow
			mov cl, 0		   	 		; 			borrow = 0

		.continue:						;
			add al, '0'					; convert int to char
			mov byte [r12+r13], al 		; result -> nextDigit = al
			dec r10		      			; OP1_remaining_digits--
			dec r11   					; OP2_remaining_digits--
			dec r13						; result_next_digit--
			jmp .loop					; GOTO loop
		
		.finished_smaller_num:			; handle case where all of OP2`s digits were read
			cmp cl, 0					; if(borrow)
			jne .handle_borrow_OP1  	;	handle_borrow()
			jmp 	.continue			; 	

;---------------------------------------------
multiply:
; OP1 * OP2 ==> result

	.init:
		push rbp		
		mov rbp, rsp
		mov rdi, 1						; init(MULTIPLY)
		call init						; load stack operands and result data to registers
		mov cl, 0						; carry = 0
		mov r14, 0						; counter for div_OP2_by_two
		mov r10, r11                    ; save original num of digit OP2
										; r10, r11 = index of last digit
	.loop:							    ; multiplication loop
		cmp r11, 0					    ; if(OP2_remaining_digits == 1)
		je .handle_one_digit 			; OP2_remaining_digits is one

	.continue_loop:
	.check_if_OP2_LSB_is_even:
		mov bl, [r9+r11]     			; bl = next char of OP2
		sub bl, '0'						; convert char to int
		mov dx, 0                       ; ensure remainder == 0
		movzx ax, bl                    ; ax <- OP2 LSB
		mov bx, 2						; bx <- 2
		div bx							; ax <- (OP2_LSB / 2) = (OP2 % 2)
		cmp dx, 1
		jne .if_even                    ; if (OP2 % 2) == 1 ==> result <- result + OP1

	.if_odd:
		add_to_result qword [OP1_pointer]

	.if_even:
	.mult_OP1:
		mov rdi, [OP1_pointer]			; OP1 *= 2
		call mult2
		mov qword [OP1_pointer], rax

	.div_OP2_by_two:					; (OP2 <- OP2 / 2)
		cmp r14, r10					; if (OP2_remaining_digits) 
		jg .finish_div					; !!!r10 constains OP2.lastDigitIndex!!!!!
										; second <- second / 2
		mov bl, [r9+r14]				; bl = next MSB char of OP2
		sub bl, '0'						; convert char to int
		add bl, cl                      ; if we had remainder, we add carry (carry 10 or 0)
		mov dx, 0 						; set the remainder 
		movzx ax, bl                    ; rax <- OP2 MSB with carry
		mov bl, 2						; rbx <- 2
		div bl							; rax <- (OP2_LSB / 2) = (OP2 % 2)
		add al, '0'						; convert int to char
		mov byte [r9+r14], al          	; update digit to new value after div
		inc r14  						;move to next digit of OP2
		cmp ah, 0                      	; update carry if there is remainder
		jg .put_carry                   ; mov carry, 10
		je .init_carry                  ; mov carry, 0

	.put_carry:
		mov cl, 10
		jmp .div_OP2_by_two
	.init_carry:
		mov cl, 0
		jmp .div_OP2_by_two

	.finish_div:
		mov cl, 0						;reset counters for next iteration
		mov r14, 0
		mov bl, [r9]              		; move OP2 lsb to bl and check if it zero
		sub bl, '0'						; convert char to int
		cmp bl, 0                       ; check if number_of_digits of OP2 was decreased by divide (MSB==0)
		jg .loop                        ; num of digit didnt change by divide, coninue multiplication
		dec r11                         ; OP2_remaining_digits--
		inc r9
		mov r10, r11                    ; save new num of digit OP2 (after deleting leading zeros)
		jmp .loop
		
	.handle_one_digit:      
		mov bl, [r9]                    ;
		sub bl, '0'						; convert char to int
		cmp bl, 0                       ; check if LSB of OP2 == 0
		je .multiply_by_zero
		cmp bl, 1                       ; check if LSB of OP2 == 1
		jna .complete
		jmp .continue_loop				; if > 1, do loop again
	.complete:
		add_to_result qword [OP1_pointer]

	.multiply_by_zero:
		delete [OP1_pointer]
		delete [OP2_pointer]
		jmp done

;---------------------------------------------
;;; AUXILLIRY MACROS FOR DIVIDE
%macro divide_second_and_factor 0
;	OP2 /= 2 
;	factor /=2

	mov rdi, [OP2_pointer]
	call div2
	;mov qword [OP2_pointer], rax
	mov rdi, [factor_pointer]
	call div2
	;mov qword [factor_pointer], rax
%endmacro

%macro update_result 0
; if (OP1 >= OP2)
;	OP1 -= OP2
;	result += factor

	.backup:							; backup pointers before operation
		push qword [OP2_pointer]			
		push qword [factor_pointer]
	.update:
		mov rdi, [OP2_pointer]
		mov rsi, [OP1_pointer]
		call bignum_abs_comparator		; compare OP1, OP2
		cmp rax, 1						;if (OP1 >= OP2)	#same as (if b>a)==> jump
		je .OP2_greater

		.OP1_greater_equal:	
			push qword [result_pointer]
			push qword [OP2_pointer]		
			mov rdi, [OP2_pointer]		; OP1 = OP1 - OP2
			call push_copy
			mov rdi, [OP1_pointer]
			call push
			call substract
			call pop
			mov qword [OP1_pointer], rax
			pop qword [OP2_pointer]
			pop qword [result_pointer]
			push qword [OP1_pointer]
			add_to_result qword [factor_pointer]	;result+= factor
			pop qword [OP1_pointer]
	.OP2_greater:
	.restore:							; restore pointers
		pop qword [factor_pointer]
		pop qword [OP2_pointer]
%endmacro


divide:
; OP1 / OP2 ==> result

	.init:
		push rbp		
		mov rbp, rsp
		mov rdi, 4						; init(DIVIDE)
		call init						; load stack operands and result data to registers
	.create_factor_bignum:
		mov rdi, 1						; create "factor" bignum and set it to 1
		call bignum_constructor_by_size ; bignum_constructor_by_size(1)
		mov qword [factor_pointer], rax ; store factor in [factor_pointer]
		mov rax, [rax]					; set factor->digit[0] = 1
		inc qword [rax]
	.recursive_call:
		call divide_rec
		update_result
	.resolve:
		delete [factor_pointer]
		delete [OP1_pointer]
		delete [OP2_pointer]
		jmp done


divide_rec:
	push rbp		
	mov rbp, rsp
	mov rdi, [OP2_pointer]
	mov rsi, [OP1_pointer]
	call bignum_abs_comparator 			; #(b,a) => b > a
	cmp rax, 0							; if (OP1 < OP2)
	je .OP1_greater_or_equal
	.OP1_smaller:
		divide_second_and_factor
		mov rsp, rbp
		pop rbp
		ret

	.OP1_greater_or_equal:

	mov rdi, [OP2_pointer]				; OP2 *= 2
	call mult2
	mov qword [OP2_pointer], rax
	mov rdi, [factor_pointer]			; factor *= 2
	call mult2
	mov qword [factor_pointer], rax

	call divide_rec
	update_result
	divide_second_and_factor
	mov rsp, rbp
	pop rbp
	ret


;;;;;;;;;;;AUXILLIRY METHODS;;;;;;;;;;;

done:
; push result and trim leading zeros									 
	mov rdi, [result_pointer]			; set parameter to be pointer to result
	call bignum_trim					; bignum_trim(result)
	call push							; push(result)
	mov rsp, rbp
	pop rbp
	ret

mult2:
;@param(RDI): pointer to bignum
;@return: 	a pointer to the bignum multiplied 
; Multiply the (bignum* ) in RDI by 2, pushes result to the Stack
; and pops and returns it as pointer in [aux_pointer]
	push rbp		
	mov rbp, rsp
	.backup:
		backup_all
	.push_and_multiply:
		call push_copy
		call push
		call add
		call pop
		mov qword [aux_pointer], rax 	;save result
	.restore:							;restore pointers and registers
		restore_all
		mov rax, qword [aux_pointer]	;return pointer to result
	mov rsp, rbp
	pop rbp
	ret


div2:
;@param(RDI): pointer to bignum OP1
;@return: 	  void 
; Divide the (bignum* ) in RDI by 2, 
	push rbp		
	mov rbp, rsp
	.backup:
		backup_registers
	.init:
		xor r14, r14					; set counters to 0
		xor rcx, rcx					;
		mov r9, [rdi]					; r9 <- pointer to OP1`s digits array
		mov r10, [rdi + 8]				; r10 <- index to OP1`s MSB
		lea r10, [r10-2]
	.divide_by_two:						; 
		
		cmp r14, r10					; if (OP1_has_remaining_digits) 
		jg .finish_div					; 
										; 
		mov bl, [r9+r14]				; bl = next MSB char of OP1
		sub bl, '0'						; convert char to int
		add bl, cl                      ; if  remainder !=0, add carry (carry 10 or 0)
		mov dx, 0 						; set the remainder 
		movzx ax, bl                    ; rax <- OP2 MSB with carry
		mov bl, 2						; rbx <- 2
		div bl							; rax <- (OP2_LSB / 2) = (OP2 % 2)
		add al, '0'						; convert int to char
		mov byte [r9+r14], al          	; update digit to new value after div
		inc r14  						;move to next digit of OP2
		cmp ah, 0                      	; update carry if there is remainder
		jg .put_carry                   ; mov carry, 10
		je .init_carry                  ; mov carry, 0

	.put_carry:
		mov cl, 10
		jmp .divide_by_two
	.init_carry:
		mov cl, 0
		jmp .divide_by_two

	.finish_div:
		mov bl, [r9]              		; move OP2 lsb to bl and check if it zero
		sub bl, '0'						; convert char to int
		cmp bl, 0                       ; check if number_of_digits of OP2 was decreased by divide (MSB==0)
		jg .complete                    ; num of digit didnt change by divide, coninue multiplication
		call bignum_trim				;trim() result if needed
	.complete:
	.restore:
		restore_registers
	mov rsp, rbp
	pop rbp
	ret


push_copy:
;@param(RDI): pointer to bignum OP1 to copy and push to stack
;@return: 	  void 
; Push a copy of the (bignum* ) in RDI, without freeing its memory 
	push rbp
	mov rbp, rsp
	.backup:
		backup_registers
	.copy_and_push:
		call bignum_copy_constructor		; copy(toCopy)
		mov rdi, rax
		call push 							; push(copy)
	.restore:								;restore pointers and registers
		restore_registers
	mov rsp, rbp
	pop rbp
	ret 									;return
