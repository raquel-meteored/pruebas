#include <stdio.h>
  
#include </usr/include/mysql/mysql.h>  

int main() {
  FILE *fread;
  FILE *fwrite;
  char name[255];
  char surname[255];

  fread = fopen("./read.txt", "r");
  fwrite = fopen("./write.txt", "w+");
  
  fscanf(fread, "%s %s" , &name, &surname);

  fprintf(fwrite, "This is testing by %s %s \n",name,surname);
  fclose(fread);
  fclose(fwrite);
}
