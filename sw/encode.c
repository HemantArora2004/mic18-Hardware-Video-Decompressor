#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct {
    double* y_image;
    double* u_image;
    double* v_image;
    double* downsampled_u_image;
    double* downsampled_v_image;
    int width;
    int height;
} ImageData;

void write_bits(FILE *fp, unsigned int data, int length);	//function prototype
ImageData getImage(const char* input_filename); 
void convertRGBToYUV(ImageData* image_data); 
void horizontalDownsampling(ImageData* image_data);

int main(int argc, char **argv) {
	int i, j, k, m, n, color, width, height, jm5, jm3, jm1, jp1, jp3, jp5, quantized[64], q[15], width_temp;
	char input_filename[200], output_filename[200], temp_string[100], quantization_choice;
	double *y_image, *u_image, *v_image, *downsampled_u_image, *downsampled_v_image, red, blue, green, dct_coeff[8][8], temp_matrix[8][8], *d_ptr;
	FILE *file_ptr;
	const int zigzag_order[] = {0, 1, 8,16, 9, 2, 3,10,17,24,32,25,18,11, 4, 5,12,19,26,33,40,48,41,34,27,20,13, 6, 7,14,21,28,
	                           35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63};
	const int Q0[] = {8,4,8,8,16,16,32,32,64,64,64,64,64,64,64};
	const int Q1[] = {8,2,2,2,4,4,8,8,16,16,16,32,32,32,32};
}


void write_bits(FILE *fp, unsigned int data, int length) {	//can write up to 32 bits at once, the least significant "length" bits of "data" will be written
	static unsigned short buffer=0;	//buffer can hold up to 16 bits, 2 bytes are written together since SRAM is 16 bits wide
	static unsigned char count=0;	//count is number of bits in use in buffer
	
	while (length>0) {
		length--;
		buffer = (buffer<<1) | ((data>>length) & 1);	//extract bit "length-1", buffer acts like a shift register in hardware
		count++;
		if (count==16) {	//16 bits in buffer, write high byte, then low byte
			fputc((buffer>>8) & 0xff, fp);
			fputc(buffer & 0xff, fp);
			count = 0;
		}
	}
}

ImageData getImage(const char* input_filename) {
    FILE* file_ptr;
    char temp_string[100];
    int i, j;
    ImageData image_data;

    // Open input file
    file_ptr = fopen(input_filename, "rb");
    if (file_ptr == NULL) {
        printf("Can't open file %s for binary reading, exiting...\n", input_filename);
        exit(1);
    } else {
        printf("Opened input file %s\n", input_filename);
    }

    // Read and check header of image
    fscanf(file_ptr, "%s", temp_string);
    if (strcmp(temp_string, "P6") != 0) {
        printf("Unexpected image type, expected P6, got %s, exiting...\n", temp_string);
        exit(1);
    }

    if (image_data.width != 640 || image_data.height != 480) {
        printf("Warning, width and height are not the expected values of 320 and 240, got %d and %d\n", image_data.width, image_data.height);
    }

    fscanf(file_ptr, "%s", temp_string);
    if (strcmp(temp_string, "255") != 0) {
        printf("Unexpected maximum number of colors, expect 255, got %s, exiting...\n", temp_string);
        exit(1);
    }

    fgetc(file_ptr);  // New line

    // Allocate memory for image data
    image_data.y_image = (double*)malloc(sizeof(double) * image_data.width * image_data.height);
    image_data.u_image = (double*)malloc(sizeof(double) * image_data.width * image_data.height);
    image_data.v_image = (double*)malloc(sizeof(double) * image_data.width * image_data.height);
    image_data.downsampled_u_image = (double*)malloc(sizeof(double) * image_data.width * image_data.height / 2);
    image_data.downsampled_v_image = (double*)malloc(sizeof(double) * image_data.width * image_data.height / 2);

    if (image_data.y_image == NULL || image_data.u_image == NULL || image_data.v_image == NULL ||
        image_data.downsampled_u_image == NULL || image_data.downsampled_v_image == NULL) {
        printf("malloc failed :(\n");
        exit(1);
    }

    // Read image data (RGB in PPM format)
    for (i = 0; i < image_data.height; i++) {
        for (j = 0; j < image_data.width; j++) {
            image_data.y_image[i * image_data.width + j] = (double)fgetc(file_ptr);  // red
            image_data.u_image[i * image_data.width + j] = (double)fgetc(file_ptr);  // green
            image_data.v_image[i * image_data.width + j] = (double)fgetc(file_ptr);  // blue
        }
    }

    if (fgetc(file_ptr) != EOF) {
        printf("Warning: not all of the data in the input PPM file was read\n");
    }

    fclose(file_ptr);

    // Return the struct containing the image data
    return image_data;
}

void convertRGBToYUV(ImageData* image_data) {
    int width = image_data->width;
    int height = image_data->height;
    
    // Loop through each pixel in the image and convert from RGB to YUV
    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            int index = i * width + j;

            // Retrieve RGB values (assuming RGB are stored in y_image, u_image, and v_image)
            float red = (float)image_data->y_image[index];   // Store red in y_image temporarily
            float green = (float)image_data->u_image[index]; // Store green in u_image temporarily
            float blue = (float)image_data->v_image[index];  // Store blue in v_image temporarily
            
            // Convert RGB to YUV
            image_data->y_image[index] = 0.257 * red + 0.504 * green + 0.098 * blue + 16.0;
            image_data->u_image[index] = -0.148 * red - 0.291 * green + 0.439 * blue + 128.0;
            image_data->v_image[index] = 0.439 * red - 0.368 * green - 0.071 * blue + 128.0;
        }
    }
}

void horizontalDownsampling(ImageData* image_data){
    int jm5, jm3, jm1, jp1, jp3, jp5;

    int width = image_data->width;
    int height = image_data->height;

    for (int i = 0; i < height; i++) 
        for (int j = 0; j < width; j+=2) {	//even j (columns) only
		jm5 = ((j-5) < 0) ? 0 : (j-5);		//use neighboring pixels to interpolate, but catch the out-of-bounds indexes
		jm3 = ((j-3) < 0) ? 0 : (j-3);
		jm1 = ((j-1) < 0) ? 0 : (j-1);
		jp1 = ((j+1) > (width-1)) ? (width-1) : (j+1);
		jp3 = ((j+3) > (width-1)) ? (width-1) : (j+3);
		jp5 = ((j+5) > (width-1)) ? (width-1) : (j+5);
		image_data->downsampled_u_image[i*width/2 + j/2] = 0.5 * image_data->u_image[i*width + j]
			+ 0.311 * (image_data->u_image[i*width + jm1] + image_data->u_image[i*width + jp1])
			- 0.102 * (image_data->u_image[i*width + jm3] + image_data->u_image[i*width + jp3])
			+ 0.043 * (image_data->u_image[i*width + jm5] + image_data->u_image[i*width + jp5]);
			
		image_data->downsampled_v_image[i*width/2 + j/2] = 0.5 * image_data->v_image[i*width + j]
			+ 0.311 * (image_data->v_image[i*width + jm1] + image_data->v_image[i*width + jp1])
			- 0.102 * (image_data->v_image[i*width + jm3] + image_data->v_image[i*width + jp3])
			+ 0.043 * (image_data->v_image[i*width + jm5] + image_data->v_image[i*width + jp5]);
	}
}

void DCT(ImageData* image_data){
    int color, width_temp;
    double red, blue, green, dct_coeff[8][8], temp_matrix[8][8], *d_ptr;

    int width = image_data->width;
    int height = image_data->height;
    
    for (int i=0; i<8; i++) {	//cache the DCT coefficients
		red = (i==0) ? sqrt(1.0/8.0) : sqrt(2.0/8.0);	//the leading coefficient in front of the cosine
		for (int j=0; j<8; j++) dct_coeff[i][j] = red * cos(M_PI/8.0*i*(j+0.5));
	}
	for (color=0; color<3; color++) {
		if (color==0) {			//Y
			d_ptr = y_image;	//provide a reference to the y_image array
			width_temp = width;		//original width
		}
		else if (color==1) {	//downsampled U
			d_ptr = downsampled_u_image;
			width_temp = width / 2;	//half the original width
		}
		else {					//downsampled V
			d_ptr = downsampled_v_image;
			width_temp = width / 2;	//half the original width
		}
		//now do the matrix multiplications
		for (int i=0; i<height; i+=8) for (int j=0; j<width_temp; j+=8) {	//i*width_temp+j is the address of the top left corner of the current 8x8 block
			for (int k=0; k<8; k++) for (int m=0; m<8; m++) {		//first matrix multiplication C * S, write to temp_matrix
				temp_matrix[k][m] = 0.0;
				for (int n=0; n<8; n++) temp_matrix[k][m] += dct_coeff[k][n] * d_ptr[(i+n)*width_temp+j+m];	//across C, down S (row i+n, column j+m)
			}
			for (int k=0; k<8; k++) for (int m=0; m<8; m++) {		//second matrix multiplication (C*S) * C^T, read from temp_matrix
				d_ptr[(i+k)*width_temp+j+m] = 0.0;			//row i+k, column j+m
				for (n=0; n<8; n++) d_ptr[(i+k)*width_temp+j+m] += temp_matrix[k][n] * dct_coeff[m][n];	//across C*S, down C^T (or across C)
			}
		}
	}
}