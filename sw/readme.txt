Readme for mic18 Video Decompressor Project

This directory contains the following source files:

mp4_to_ppm.py
decode_m1.c
decode_m2.c
decode_m3.c
encode_all.c

To run the mp4_to_ppm program, you will need:

numpy
OpenCV

These files are based on code originally written by Nicola Nicolici and Jason Thong for the 3DQ5 Project. The original code has been adapted to process video data (in the form of .mp4 files) instead of single images, making it capable of converting video frames into a series of .ppm images for further processing.

The data flow of the project is as follows:

mp4_to_ppm.py 

This step converts an .mp4 video file into a series of .ppm images, where each frame of the video is saved as a separate .ppm file. The conversion process is done using numpy and OpenCV to extract frames from the video and save them in the PPM format.

encode_all (mandatory)

This step is mandatory to run in software. It encodes the .ppm files to a .mic18 file (McMaster Image Compression, revision 18).  The details of encoding are provided in the project document. As a summary, first  we do color space conversion, then downsampling of U and V, then IDCT on 8x8 blocks, and finally lossless decoding and quantization.

decode_m3 (mandatory)

This is a reference for milestone 3 in hardware. The .mic18 file is lossless decoded and dequantization is applied, the result is a .sram_d2 file. This file serves as the input for milestone 2 (this file is organized exactly like the SRAM, so in the testbench it can be used to initialize the SRAM for milestone 2). Also, this file can be used to verify milestone 3 is working properly in hardware (testbench).

decode_m2 (mandatory)

This is a reference for milestone 2 in hardware. The .sram_d2 file contains pre-IDCT data. We compute the IDCT on this data and the result is written to a .sram_d1 file. Again, this is organized like the SRAM in hardware, which makes it easy to initialize and compare the final data in the SRAM in a testbench.

decode_m1  (mandatory)

This is a reference for milestone 1 in hardware. The .sram_d1 file contains YUV data, but the U and V are still downsampled versions. Horizontal interpolation is done to upsample the odd columns of U and V (from the even columns, each row is processed independently). Finally, for each pixel independently, the YUV data is converted to RGB and the data is written back to the SRAM.