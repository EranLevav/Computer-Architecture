#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "./calc.h"
/*
 * Bignum Functionality
 */
const int INITIAL_BIGNUM_SIZE = 10;
const int DIGIT_INCREMENT_SIZE= 10;

bignum* bignum_constructor(char firstDigit) {
    bignum* num = (bignum*)malloc(sizeof(bignum));
    int isNegative = firstDigit =='_' ? 1 : 0;
    num ->isNegative= isNegative;
    num-> number_of_digits = !isNegative;
    num-> digit = (char *) malloc (INITIAL_BIGNUM_SIZE);
    if (!isNegative)
        num->digit[0]= firstDigit;
    return num;
}

//Creates a new bignum with @param(number_of_digits) 0's
bignum* bignum_constructor_by_size(long number_of_digits) {
    int i =0;
    bignum* num = (bignum* )malloc(sizeof(bignum));
    num ->isNegative= 0;
    num-> number_of_digits = number_of_digits + 1;
        num-> digit = (char *) malloc (number_of_digits+1);
    num-> digit[number_of_digits]='\0';
    for (i=0; i < number_of_digits; i ++)
        num-> digit[i]='0';
    return num;
}

//Steal @param(toCopy)
bignum* bignum_move_constructor(bignum* toCopy){
    bignum* newNum = (bignum*)malloc(sizeof(bignum));
    newNum -> digit = toCopy -> digit;
    newNum -> number_of_digits = toCopy -> number_of_digits;
    newNum -> isNegative = toCopy -> isNegative;
    toCopy -> digit = NULL;
    toCopy -> number_of_digits = 0;
    return newNum;
}
bignum* bignum_copy_constructor(bignum* toCopy){
    bignum* newNum = (bignum*)malloc(sizeof(bignum));
    newNum -> digit = (char*)malloc(toCopy -> number_of_digits);
    memcpy(newNum -> digit, toCopy -> digit,  toCopy -> number_of_digits);
    newNum -> number_of_digits = toCopy -> number_of_digits;
    newNum -> isNegative = toCopy -> isNegative;
    return newNum;
}
void bignum_destructor(bignum* toDelete){
    free(toDelete->digit);
    free(toDelete);
}
//increment char array's size every ${DIGIT_INCREMENT_SIZE} digits
void bignum_ensureCapacity(bignum* num){
    long arraySize=num->number_of_digits;
    if((arraySize >= INITIAL_BIGNUM_SIZE)
       && (arraySize % DIGIT_INCREMENT_SIZE==0)){
        char* newDigitsArray = (char*)realloc(num->digit , sizeof(char) * (arraySize + DIGIT_INCREMENT_SIZE));
        num -> digit= newDigitsArray;
    }
}

void bignum_addDigit(bignum* num, char digitToAdd) {
    bignum_ensureCapacity(num);
    num->digit[num->number_of_digits]= digitToAdd;
    num-> number_of_digits ++;
}

//@return 1 iff a > b
int bignum_abs_comparator(bignum* a, bignum* b) {
    //printf("\n%s > %s?\n", a->digit, b->digit);
    int aIsBigger=1;
    int i;
    if (a->number_of_digits > b->number_of_digits)
        return aIsBigger;
    else if ( a->number_of_digits == b->number_of_digits ) {
        for (i = 0; i < a->number_of_digits; i++){
            if (a->digit[i] > b->digit[i])
                return aIsBigger;
            if (a->digit[i] < b->digit[i])
                return !aIsBigger;
        }
    }
    else
        return !aIsBigger;
    return !aIsBigger;
}
void negate(bignum* num){
    //check if num === 0
    if(num->number_of_digits == 2 && num->digit[0] == '0')
        return;
    num->isNegative = num->isNegative ? 0 : 1;
}
void absBignum(bignum* num){
    if (num->isNegative)
        negate(num);
}

int isZero(bignum* num){
    return num && (num->number_of_digits == 2) && (num->digit[0]=='0');
}
void bignum_trim(bignum* num){
    long numOfDigits = num->number_of_digits - 1;
    long actualNumOfDigits;
    if (numOfDigits <= 1)       //one digit number
        return; 
    long leadingZerosCounter = 0;
    long i = 0;
    while (num->digit[i] == '0')
        i++;  
    leadingZerosCounter= i;
    if(leadingZerosCounter==0)  //no need to trim
        return;
    if(leadingZerosCounter == numOfDigits){ // num === 0
        num -> digit[0] = '0';
        num -> digit[1] = '\0';
        num -> number_of_digits = 2;
        return;
    }
    actualNumOfDigits= numOfDigits - leadingZerosCounter;
    for (i = 0; i < actualNumOfDigits; i++)
        num->digit[i] = num-> digit[i + leadingZerosCounter];
    num->digit[actualNumOfDigits] = '\0';
    num->number_of_digits = actualNumOfDigits + 1;
}

/*
 * Stack Functionality
 */

//Global variables
bignum ** Stack;
int stackSize;

//Stack Methods
void initStack(){
    Stack = (bignum **) malloc (1024);
    stackSize = 0;
}
void push(bignum* element){
    Stack[stackSize]= element;
    stackSize++;
}

bignum* pop(){
    if(!stackSize){
        printf("stack underflow");
        return NULL;
    }
    bignum* topElement = bignum_move_constructor(peek()); //copy element to different pointer
    free(Stack[stackSize-1]);
    stackSize--;
    return topElement;
}

bignum* peek(){
    return Stack[stackSize-1];
}

bignum* peekSecond(){
    return Stack[stackSize-2];
}
void clearStack(){
    while(stackSize){
        stackSize--;
        bignum_destructor(Stack[stackSize]);        
    }
}
void printStack(){
    printf("SIZE:%d\n", stackSize);
    for( int i=0; i< stackSize; i++)
        printf("[%d] (#%ld) %c%s\n", i, Stack[i]-> number_of_digits, Stack[i]->isNegative? '-': '+', Stack[i]->digit);
    putchar('\n');
}

void switchStackTop(){
    bignum * stackTop = peek();
    bignum * stackSecondElement = peekSecond();
    Stack[stackSize-1] = stackSecondElement;
    Stack[stackSize-2] = stackTop;
}

/*
 * Arithmetic help functions
 */
void addProcessor(){
    bignum * b = peek();
    bignum * a = peekSecond();
    int AGreaterThanB = bignum_abs_comparator(a,b);
    int aIsNeg = a->isNegative;
    int bIsNeg = b->isNegative;
    absBignum(a);
    absBignum(b);
    if (AGreaterThanB)  // The first bigNum is the bigger in abs
        switchStackTop();
    if (aIsNeg && bIsNeg) {
        add();
        negate(peek());
    }
    if (!aIsNeg && !bIsNeg) {
        add();
    }
    if (!aIsNeg && bIsNeg) {
        substract();
        if (!AGreaterThanB)
             negate(peek());
    }
    if (aIsNeg && !bIsNeg) {
        substract();
        if (AGreaterThanB) 
            negate(peek());
    }
}

void substractProcessor() {
    bignum *b = peek();
    bignum *a = peekSecond();
    int AGreaterThanB = bignum_abs_comparator(a, b);
    int aIsNeg = a->isNegative;
    int bIsNeg = b->isNegative;
    absBignum(a);
    absBignum(b);

    if (AGreaterThanB)  // The first bigNum is the bigger in abs
        switchStackTop();
    if (!aIsNeg && !bIsNeg){
        substract();
        if (!AGreaterThanB) 
            negate(peek());
    }
    if (aIsNeg && bIsNeg){
        substract();
        if (AGreaterThanB) 
            negate(peek());
    }
    if (!aIsNeg && bIsNeg) 
        add();
    if (aIsNeg && !bIsNeg) {
        add();
        negate(peek());
    }
}

void multiplyProcessor(){
    bignum * b = peek();
    bignum * a = peekSecond();
    int aIsNeg = a->isNegative;
    int bIsNeg = b->isNegative;
    absBignum(a);
    absBignum(b);
    int AGreaterThanB = bignum_abs_comparator(a, b);
    if (AGreaterThanB)  // The first bigNum is the bigger in abs
        switchStackTop();
    multiply();
    if ((aIsNeg && !bIsNeg) || (!aIsNeg && bIsNeg))
        negate(peek());
}

void divideProcessor(){
    bignum * b = peek();
    bignum * a = peekSecond();
    if (isZero(b)){
        printf("ERROR: can't divide by zero. Popping operands.\n");
        pop();
        pop();
        return;
    }
    int aIsNeg = a->isNegative;
    int bIsNeg = b->isNegative;
    absBignum(a);
    absBignum(b);
    // int AGreaterThanB = bignum_abs_comparator(a, b);
    // if (AGreaterThanB)  // The first bigNum is the bigger in abs
    switchStackTop();
    divide();
    if ((aIsNeg && !bIsNeg) || (!aIsNeg && bIsNeg))
        negate(peek());
}


//Main
int main ()
{
    initStack();
    char ch = getchar();
    bignum * currentNewBigNum = NULL;
    while(ch!='q') {
        if (((ch >= '0') && (ch <= '9'))|| (ch=='_')) {
            if (currentNewBigNum == NULL) {
                currentNewBigNum = bignum_constructor(ch);
                push(currentNewBigNum);
            }
            else
                bignum_addDigit(currentNewBigNum, ch);
        }
        else {
            if (currentNewBigNum){
                bignum_addDigit(currentNewBigNum, '\0'); //add delimiter to bignum
                bignum_trim(currentNewBigNum);          //trim leading zeros
                currentNewBigNum = NULL;
            }
            switch (ch) {
                case '+': addProcessor();
                    break;
                case '-': substractProcessor();
                    break;
                case '*': multiplyProcessor();
                    break;
                case '/': divideProcessor();
                    break;
                case 'p':
                    if (peek()->isNegative)
                        putchar('-');
                    printf("%s\n", peek()->digit);
                    break;
                case 'c':
                    clearStack();
                    break;
                //additional cases for testing
                case 'x':
                    printStack();
                    break;
                case 't':
                    printf("%p\n", peek());
                    printf("%p\n", peekSecond());
                    break;
            }
        }
        ch = getchar();
    }
    clearStack();
    free(Stack);
    return 0;
}