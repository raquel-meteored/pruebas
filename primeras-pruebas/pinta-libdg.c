

#include "gd.h"
#include <stdio.h>

int main (){
	gdImagePtr im;
	/*gdFontPtr titulo;*/
	FILE *pngout, *jpegout;
	int black;
	int white;
	int red;
	im = gdImageCreateTrueColor (64,64);
	/*titulo = gdFont() ;*/

        black = gdImageColorAllocate(im, 0, 0, 0);
        white = gdImageColorAllocate(im, 255, 255, 255);
        red = gdImageColorAllocate(im, 255, 0, 0);
        

	gdImageLine(im, 0,0,63,63, white);
	gdImageLine(im, 0,63,63,63, red);
	gdImageLine(im, 63,0,63,63, red);
	gdImageRectangle(im, 10, 10, 53, 53, red);
	gdImageFilledRectangle(im, 20, 20, 43, 43, red);
        /*gdImageChar(im, titulo, 30, 30, )*/
 

	pngout = fopen("test.png", "wb");
	jpegout = fopen("test.jpg", "wb");
	gdImagePng(im ,pngout);
	gdImageJpeg(im , jpegout, -1);

	
	fclose(pngout);
	fclose(jpegout);

	gdImageDestroy (im);
}
