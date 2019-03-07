typedef struct bignum {
    char *digit;
    long number_of_digits;
    int isNegative;
   
} bignum;

bignum* bignum_constructor(char firstDigit);
bignum* bignum_constructor_by_size(long number_of_digits);
//bignum* bignum_copy_constructor(bignum* source);
bignum* bignum_move_constructor(bignum* toCopy);
void    bignum_ensureCapacity(bignum* num);
void    bignum_addDigit(bignum* num, char digitToAdd);
int     bignum_abs_comparator(bignum* a, bignum* b);
void    negate(bignum* num);
void    absBignum(bignum* num);
void    bignum_trim(bignum* num);

void    initStack();
void    push(bignum* element);
bignum* pop();
bignum* peek();
bignum* peekSecond();
void    clearStack();
void    printStack();
void    switchStackTop();

void    addProcessor();
void    substractProcessor();
void    multiplyProcessor();
void    divideProcessor();

// void    resolve(int result);
// void    add2();
// void    substract2();
// void    multiply2();
// void    divide2();

/*
 * Assembler Functions
 */

extern void substract(void);
extern void add(void);
extern void multiply(void);
extern void divide(void);