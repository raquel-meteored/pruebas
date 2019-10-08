#include <stdio.h>
 
/* function declaration */
void func(void);
 
static int count = 5; /* global variable */
 
int main() {

   while(count--) {
      func();
   }
	
   return 0;
}

/* function definition */
void func( void ) {


   int number;
   static int i = 5; /* local static variable */

   scanf("%d", &number);
   i++;

   printf("i is %d and count is %d\n", i, count);
   printf("number entered; %d\n",number);
}
