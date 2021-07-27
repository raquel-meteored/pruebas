
/*hola*/
#include "gd.h"
#include <stdio.h>
#include <stdlib.h>

void save_png(gdImagePtr im, const char *filename)
{
    FILE *fp;
    fp= fopen(filename, "wb");
    if (!fp) {
        fprintf(stderr, "Can't save png image %s\n", filename);
        return;
    }
    gdImagePng(im,fp);
    fclose(fp);
}


int main (){
	gdImagePtr im, im2, im3;
	/*gdFontPtr titulo;*/
	/*FILE *pngout, *jpegout;*/
	int black, white, red, color;
	int r, g, b;
	im = gdImageCreateTrueColor (64,64);
	im3 = gdImageCreateTrueColor (64,64);
	/*titulo = gdFont() ;*/

        black = gdImageColorAllocate(im, 0, 0, 0);
        white = gdImageColorAllocate(im, 255, 255, 255);
        red = gdImageColorAllocate(im, 255, 0, 0);
        r = rand() % 255;
        g = rand() % 255;
        b = rand() % 255;
        color = gdImageColorAllocate(im3, r, g, b);


    gdImageFilledRectangle(im, 0, 0, 63, 63, white);
	gdImageLine(im, 0,0,63,63, white);
	gdImageLine(im, 0,63,63,63, red);
	gdImageLine(im, 63,0,63,63, red);
	gdImageRectangle(im, 10, 10, 53, 53, red);
	gdImageFilledRectangle(im, 20, 20, 43, 43, red);
    gdImageTrueColorToPalette(im, 1, 256);
        /*gdImageChar(im, titulo, 30, 30, )*/

    im2 = gdImageCropAuto(im, GD_CROP_SIDES);

    gdImageColorAllocate(im3, 255, 255, 255);
    gdImageFilledRectangle(im3, 20, 20, 43, 43, color);

    printf("(%i, %i, %i)\n",r, g, b);
    save_png(im,"test2.png");
    save_png(im2,"test2-crop.png");
    save_png(im3,"test2-colorand.png");
/*	pngout = fopen("test.png", "wb");
	jpegout = fopen("test.jpg", "wb");
	gdImagePng(im ,pngout);
	gdImageJpeg(im , jpegout, -1);

	fclose(pngout);
	fclose(jpegout); */

	gdImageDestroy (im);
	/*hola*/
	gdImageDestroy (im2);
	gdImageDestroy (im3);
}
