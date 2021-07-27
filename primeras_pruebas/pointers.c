#include <stdio.h>

int main() 
{
   int A[5]={5,8,9,6,10}; 
   int *p,*q;
   p=&A[0];
   q=&A[3];

 /*valor del número que apunta*/
    printf ("Escribe valor del pointer \n");
    printf("%d\n",*p);
   printf("%d\n",*q);

   /*suma o resta al valor que apunta*/
   printf ("suma y resta valor del pointer  \n");
   printf("%d\n",*p+2);
   printf("%d\n",*q-2);

  printf ("suma y resta posicion pointer \n");
  printf("%d\n",*(p+2));
  printf("%d\n",*(q-2));	  


}
