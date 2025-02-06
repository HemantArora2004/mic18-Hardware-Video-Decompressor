module milestone1 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// reset                      			////////////
		input logic resetn,                       // async reset
		
		/////// enable                      	   ///////////
		input logic ena,                          // enable module
		output logic done,

		
		/////// SRAM Interface                    ////////////
		output logic [17:0] SRAM_address,
		output logic [15:0] SRAM_write_data,
		output logic SRAM_we_n,
		input  logic [15:0] SRAM_read_data
);

parameter [17:0] U_OFFSET = 18'd38400;
parameter [17:0] V_OFFSET = 18'd57600;
parameter [17:0] RGB_OFFSET = 18'd146944;

// Even pixel counter for keeping track of the address offset
logic [17:0] even_pixel_counter;
logic [7:0] col_counter;
logic [17:0] write_address_counter;


// For SRAM


// For Storing Sram Data
// 0 is for current pixel, 1 is for FIR
logic [15:0] SRAM_Y;
logic [15:0] SRAM_U [1:0];
logic [15:0] SRAM_V [1:0];


// Shift Registers for FIR
logic [7:0] FIR_U [5:0];
logic [7:0] FIR_V [5:0];

// FIR MACs
logic [31:0] U_prime;
logic [31:0] V_prime;

// CSC MACs
// 0 is for even, 1 is for odd
logic [31:0] Y_CSC [1:0];
logic [31:0] red [1:0];
logic [31:0] green [1:0];
logic [31:0] blue [1:0];


// For multipliers 
logic [31:0] op1 [1:0];
logic [31:0] op2 [1:0];
logic [31:0] op3 [1:0];
logic [31:0] result1;
logic [31:0] result2;
logic [31:0] result3;

logic toggle; 


//logic [31:0] SRAM_WRITE_DATA_TEMP [1:0];

// State Def
typedef enum logic [4:0] {
	S_IDLE,
	S_LI1,
	S_LI2, 
	S_LI3, 
	S_LI4, 
	S_LI5, 
	S_LI6, 
	S_LI7, 
	S_LI8, 
	S_LI9, 
	S_LI10, 
	S_LI11, 
	S_LI12, 
	S_LI13,
	S_LI14, 
	S_LI15,
	S_CC1, 
	S_CC2, 
	S_CC3, 
	S_CC4, 
	S_CC5, 
	S_CC6, 
	S_LO1,
	S_LO2, 
	S_LO3, 
	S_LO4, 
	S_LO5,
	S_LO6, 
	S_LO7, 
	S_LO8, 
	S_LO9,
	S_DONE
} state_type;


state_type state;

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin 
        // Reset all signals to their default values
        
        state <= S_IDLE;                          // Assuming 'state' is of type enum
        even_pixel_counter <= 18'd0;               // 18-bit counter
		  col_counter <= 8'd0;
		  write_address_counter <= 18'd0;
        
         // SRAM control and data signals
        SRAM_address <= 18'd0;                     // 18-bit SRAM address
        SRAM_write_data <= 16'd0;                  // 16-bit SRAM write data
        SRAM_we_n <= 1'b1;                         // 1-bit SRAM write enable
        
        // SRAM Y, U, V data (16-bit each)
        SRAM_Y <= 16'd0;
        SRAM_U[0] <= 16'd0;                       // 16-bit SRAM U data for current pixel
        SRAM_U[1] <= 16'd0;                       // 16-bit SRAM U data for FIR
        SRAM_V[0] <= 16'd0;                       // 16-bit SRAM V data for current pixel
        SRAM_V[1] <= 16'd0;                       // 16-bit SRAM V data for FIR
        
        // Shift Registers for FIR (6 entries, 8-bit each)
        FIR_U[0] <= 8'd0;
        FIR_U[1] <= 8'd0;
        FIR_U[2] <= 8'd0;
        FIR_U[3] <= 8'd0;
        FIR_U[4] <= 8'd0;
        FIR_U[5] <= 8'd0;
        
        FIR_V[0] <= 8'd0;
        FIR_V[1] <= 8'd0;
        FIR_V[2] <= 8'd0;
        FIR_V[3] <= 8'd0;
        FIR_V[4] <= 8'd0;
        FIR_V[5] <= 8'd0;
        
        // FIR MACs (32-bit each)
        U_prime <= 32'd0;
        V_prime <= 32'd0;
        
        // CSC MACs (32-bit each)
        Y_CSC[0] <= 32'd0;                        // Even
        Y_CSC[1] <= 32'd0;                        // Odd
        red[0] <= 32'd0;                          // Even red
        red[1] <= 32'd0;                          // Odd red
        green[0] <= 32'd0;                        // Even green
        green[1] <= 32'd0;                        // Odd green
        blue[0] <= 32'd0;                         // Even blue
        blue[1] <= 32'd0;                         // Odd blue
        
        // For multipliers (32-bit each)
        op1[0] <= 32'd0;
        op1[1] <= 32'd0;
        op2[0] <= 32'd0;
        op2[1] <= 32'd0;
        op3[0] <= 32'd0;
        op3[1] <= 32'd0;
		  
		  toggle <= 1'b0;
		  done <= 1'b0;
		  
    end else begin
		SRAM_we_n <= 1'b1; // By default don't write anything
		case(state) 
			S_IDLE: begin
				done <= 1'b0;
				state <= S_IDLE;
				if(ena == 1'b1) begin 
					state <= S_LI1;
				end
         end
					
			S_LI1: begin 
				state <= S_LI2;
				// Memory Writes
				// Memory Reads
				SRAM_address <= {1'b0, even_pixel_counter[17:1]};
				SRAM_we_n <= 1'b1;
			end
			
			S_LI2: begin 
				state <= S_LI3;
				// Memory Writes
				// Memory Reads
				SRAM_address <= {2'b00, even_pixel_counter[17:2]} + U_OFFSET;
				SRAM_we_n <= 1'b1;
			end
			
			S_LI3: begin 
				state <= S_LI4;
				// Memory Writes
				// Memory Reads
				SRAM_address <= {2'b00, even_pixel_counter[17:2]} + V_OFFSET;
				SRAM_we_n <= 1'b1;
			end
			
			S_LI4: begin
				state <= S_LI5;	
				// Memory Writes
				// Memory Reads
				SRAM_address <= {2'b00, even_pixel_counter[17:2]} + U_OFFSET + 18'd1;
				SRAM_we_n <= 1'b1;
				
				// Memory Latches
				SRAM_Y <= SRAM_read_data;
			end
			
			S_LI5: begin 
				state <= S_LI6;
				// Memory Writes
				// Memory Reads
				SRAM_address <= {2'b00, even_pixel_counter[17:2]} + V_OFFSET + 18'd1;
				SRAM_we_n <= 1'b1;
				
				// Memory Latches
				SRAM_U[0] <= SRAM_read_data;
			end
			
			S_LI6: begin
				state <= S_LI7;
				// Memory Writes
				// Memory Reads
				// Memory Latches
				SRAM_V [0] <= SRAM_read_data;
			end
			
			S_LI7: begin 
				state <= S_LI8;
				// Memory Writes
				// Memory Reads
				// Memory Latches
				SRAM_U [1] <= SRAM_read_data;
			end
			
			S_LI8: begin 
				state <= S_LI9;
				// Memory Writes
				// Memory Reads
				// Memory Latches
				SRAM_V [1] <= SRAM_read_data;
			end
			
			S_LI9: begin
				state <= S_LI10;
				//	Memory Write
				// Memory Read, Y for NEXT pixel
				SRAM_address <= (even_pixel_counter + 18'd2) >> 1;
				SRAM_we_n <= 1'b1;
				
				
				// Setup FIRs for first pixel in the row
				FIR_U[0] <= SRAM_U[1][7:0];
				FIR_U[1] <= SRAM_U[1][15:8];
				FIR_U[2] <= SRAM_U[0][7:0];
				FIR_U[3] <= SRAM_U[0][15:8];
				FIR_U[4] <= SRAM_U[0][15:8];
				FIR_U[5] <= SRAM_U[0][15:8];
        
				FIR_V[0] <= SRAM_V[1][7:0];
				FIR_V[1] <= SRAM_V[1][15:8];
				FIR_V[2] <= SRAM_V[0][7:0];
				FIR_V[3] <= SRAM_V[0][15:8];
				FIR_V[4] <= SRAM_V[0][15:8];
				FIR_V[5] <= SRAM_V[0][15:8];
				
				// Even Color Space Converison for first pixel
				op1[0] <= {{24{1'b0}}, SRAM_Y[15:8]} - 32'd16; 
				op1[1] <= 32'd76284;
			
			
			end
					
			S_LI10: begin 
				state <= S_LI11;
				//	Memory Writes
				//	Memory Reads, U for next pixel
				if(toggle == 1'b0) begin 
					SRAM_address <= ((even_pixel_counter + 18'd8) >> 2) + U_OFFSET;
					SRAM_we_n <= 1'b1;
				end else begin 
					SRAM_address <= ((even_pixel_counter + 18'd2) >> 2) + U_OFFSET;
					SRAM_we_n <= 1'b1;
				end
				
				// Memory Writes 
				// Memory Latches
				
				// Even Color Space Converison for first pixel
				Y_CSC[0] <= result1; 
				
				// Odd Color Space Converison for first pixel
				op1[0] <= {{24{1'b0}}, SRAM_Y[7:0]} - 32'd16; 
				op1[1] <= 23'd76284;
				
				green[1] <= green[1] - result2; 
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[0]} + {1'b0, FIR_U[5]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd21;
				
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[0]} + {1'b0, FIR_V[5]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd21;
				
			end
			
			S_LI11: begin 
				state <= S_LI12;
				//	Memory Writes
				//	Memory Reads, V for NEXT pixel
				if(toggle == 1'b0) begin 
					SRAM_address <= ((even_pixel_counter + 18'd8) >> 2) + V_OFFSET;
					SRAM_we_n <= 1'b1;
				end else begin 
					SRAM_address <=  ((even_pixel_counter + 18'd2) >> 2) + V_OFFSET;
					SRAM_we_n <= 1'b1;
				
				end
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_V[0][15:8]} - 32'd128;
				op1[1] <= 32'd104595;
				
				// Odd Color Space Converison
				Y_CSC[1] <= result1; 
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[1]} + {1'b0, FIR_U[4]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd52;
				U_prime <= 32'd128 + result2;
			
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[1]} + {1'b0, FIR_V[4]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd52;
				V_prime <= 32'd128 + result3;
			end
		
			S_LI12: begin 
				state <= S_LI13;
				// Memory Writes
				//	Memory Reads
				// Memory Latches
				SRAM_Y <= SRAM_read_data;
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, {SRAM_U[0][15:8]}} - 32'd128;
				op1[1] <= 32'd25624;
				red[0] <= Y_CSC[0] + result1;
				
				// Odd Color Space Converison
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[2]} + {1'b0, FIR_U[3]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd159;
				U_prime <= U_prime - result2;
			
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[2]} + {1'b0, FIR_V[3]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd159;
				V_prime <= V_prime - result3;
			end
			
			S_LI13: begin
				state <= S_LI14;
				//	Memory Reads
				// Memory Writes 
				// Memory Latches
				if(toggle == 1'b0) begin 
					SRAM_U[1] <= SRAM_read_data;
				end else begin 
					SRAM_U[0] <= SRAM_read_data;
				end
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_V[0][15:8]} - 32'd128;
				op1[1] <= 32'd53281;
				op2[0] <= {{24{1'b0}}, SRAM_U[0][15:8]} - 32'd128;
				op2[1] <= 32'd132251;
				green[0] <= Y_CSC[0] - result1;
				
				// Odd Color Space Converison
				
				// U FIR
				U_prime <= U_prime + result2;
			
				// V FIR
				V_prime <= V_prime + result3;
			end
			
			S_LI14: begin
				state <= S_LI15;
				//	Memory Reads
				// Memory Writes
				// Memory Latches
				if(toggle == 1'b0) begin 
					SRAM_V[1] <= SRAM_read_data;
				end else begin 
					SRAM_V[0] <= SRAM_read_data;
				end
				// Even Color Space Converison 
				green[0] <= green[0] - result1;
				blue[0] <= Y_CSC[0] + result2;
				// Odd Color Space Converison
				op1[0] <= {{8{V_prime[31]}}, V_prime[31:8]} - 32'd128;
				op1[1] <= 32'd104595;
				op2[0] <= {{8{U_prime[31]}}, U_prime[31:8]} - 32'd128;
				op2[1] <= 32'd25624;
				op3[0] <= {{8{U_prime[31]}}, U_prime[31:8]} - 32'd128;
				op3[1] <= 32'd132251;
				// U FIR			
				// V FIR
				
				if(toggle == 1'b0) begin 
					SRAM_U[0] <= {SRAM_U[0][7:0], 8'b0};
					SRAM_V[0] <= {SRAM_V[0][7:0], 8'b0};
				end else begin 
					SRAM_U[1] <= {SRAM_U[1][7:0], 8'b0};
					SRAM_V[1] <= {SRAM_V[1][7:0], 8'b0};
				end
			end
			
			S_LI15: begin 
				state <= S_CC1;
				//	Memory Reads
				SRAM_address <= (even_pixel_counter + 18'd4) >> 1;
				SRAM_we_n <= 1'b1;
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_Y[15:8]} - 32'd16; 
				op1[1] <= 32'd76284;
				// Odd Color Space Converison
				op2[0] <= {{8{V_prime[31]}}, V_prime[31:8]} - 32'd128;
				op2[1] <= 32'd53281;
				red[1] <= Y_CSC[1] +  result1;
				green [1] <= Y_CSC[1] - result2;
				blue[1] <= Y_CSC[1] + result3;
				// U FIR
				FIR_U[0] <= SRAM_U[1][15:8];    // Insert new data into the first element
           	FIR_U[1] <= FIR_U[0];       // Shift FIR_U[0] to FIR_U[1]
   			FIR_U[2] <= FIR_U[1];       // Shift FIR_U[1] to FIR_U[2]
				FIR_U[3] <= FIR_U[2];       // Shift FIR_U[2] to FIR_U[3]
				FIR_U[4] <= FIR_U[3];       // Shift FIR_U[3] to FIR_U[4]
            FIR_U[5] <= FIR_U[4];       // Shift FIR_U[4] to FIR_U[5]
				// V FIR
				FIR_V[0] <= SRAM_V[1][15:8];    // Insert new data into FIR_V[0]
            FIR_V[1] <= FIR_V[0];       // Shift FIR_V[0] to FIR_V[1]
            FIR_V[2] <= FIR_V[1];       // Shift FIR_V[1] to FIR_V[2]
            FIR_V[3] <= FIR_V[2];       // Shift FIR_V[2] to FIR_V[3]
         	FIR_V[4] <= FIR_V[3];       // Shift FIR_V[3] to FIR_V[4]
         	FIR_V[5] <= FIR_V[4];       // Shift FIR_V[4] to FIR_V[5]
				// toggle
				toggle <= ~toggle;
				even_pixel_counter <= even_pixel_counter + 18'd2;
				col_counter <= col_counter + 8'd1;
			end
					
			S_CC1: begin 
				state <= S_CC2;
				//	Memory Writes
				//	Memory Reads
				if(toggle == 1'b0) begin 
					SRAM_address <= ((even_pixel_counter + 18'd8) >> 2) + U_OFFSET;
					SRAM_we_n <= 1'b1;
				end else begin 
					SRAM_address <= ((even_pixel_counter + 18'd2) >> 2) + U_OFFSET;
					SRAM_we_n <= 1'b1;
				end
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				Y_CSC[0] <= result1; // For pixel n
				
				// Odd Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_Y[7:0]} - 32'd16; // For pixel n + 1
				op1[1] <= 23'd76284;
				
				green[1] <= green[1] - result2; // for pixel n-1
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[0]} + {1'b0, FIR_U[5]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd21;
				
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[0]} + {1'b0, FIR_V[5]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd21;
				
			end
			
			S_CC2: begin 
				state <= S_CC3;
				//	Memory Writes
				//	Memory Reads
				if(toggle == 1'b0) begin 
					SRAM_address <= ((even_pixel_counter + 18'd8) >> 2) + V_OFFSET;
					SRAM_we_n <= 1'b1;
				end else begin 
					SRAM_address <=  ((even_pixel_counter + 18'd2) >> 2) + V_OFFSET;
					SRAM_we_n <= 1'b1;
				
				end
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_V[0][15:8]} - 32'd128;
				op1[1] <= 32'd104595;
				
				// Odd Color Space Converison
				Y_CSC[1] <= result1; // For pixel n + 1
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[1]} + {1'b0, FIR_U[4]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd52;
				U_prime <= 32'd128 + result2;
			
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[1]} + {1'b0, FIR_V[4]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd52;
				V_prime <= 32'd128 + result3;
			end
		
			S_CC3: begin 
				state <= S_CC4;
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET;
				SRAM_write_data <= { 
					 (red[0][31] == 1) ? 8'd0 :            // If blue[0] is negative, assign 8'd0
					 (red[0][31:24] != 8'd0) ? 8'd255 :    // If the upper 8 bits of blue[0] are non-zero, assign 8'b255
					  red[0][23:16],                       // Otherwise, assign the lower 8 bits of blue[0]

					 (green[0][31] == 1) ? 8'd0 :             // If red[1] is negative, assign 8'd0
					 (green[0][31:24] != 8'd0) ? 8'd255 :     // If the upper 8 bits of red[1] are non-zero, assign 8'b255
					  green[0][23:16]                         // Otherwise, assign the lower 8 bits of red[1]
				};
				
				//SRAM_WRITE_DATA_TEMP[0] <= red[0];
				//SRAM_WRITE_DATA_TEMP[1] <= green[0];
				SRAM_we_n <= 1'b0;
				//	Memory Reads
				// Memory Latches
				SRAM_Y <= SRAM_read_data;
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, {SRAM_U[0][15:8]}} - 32'd128;
				op1[1] <= 32'd25624;
				red[0] <= Y_CSC[0] + result1;
				
				// Odd Color Space Converison
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[2]} + {1'b0, FIR_U[3]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd159;
				U_prime <= U_prime - result2;
			
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[2]} + {1'b0, FIR_V[3]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd159;
				V_prime <= V_prime - result3;
			end
			
			S_CC4: begin
				state <= S_CC5;
				//	Memory Reads
				// Memory Writes 
				SRAM_address <= write_address_counter + RGB_OFFSET + 18'd1;
				SRAM_write_data <= { 
					 (blue[0][31] == 1) ? 8'd0 :           // If green[1] is negative, assign 8'd0
					 (blue[0][31:24] != 8'd0) ? 8'd255 :   // If the upper 8 bits of green[1] are non-zero, assign 8'b255
					  blue[0][23:16],                      // Otherwise, assign the lower 8 bits of green[1]

					 (red[1][31] == 1) ? 8'd0 :            // If blue[1] is negative, assign 8'd0
					 (red[1][31:24] != 8'd0) ? 8'd255 :    // If the upper 8 bits of blue[1] are non-zero, assign 8'b255
					  red[1][23:16]                        // Otherwise, assign the lower 8 bits of blue[1]
				};
				//SRAM_WRITE_DATA_TEMP[0] <= blue[0];
				//SRAM_WRITE_DATA_TEMP[1] <= red[1];
				SRAM_we_n <= 1'b0;
				// Memory Latches
				if(toggle == 1'b0) begin 
					SRAM_U[1] <= SRAM_read_data;
				end else begin 
					SRAM_U[0] <= SRAM_read_data;
				end
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_V[0][15:8]} - 32'd128;
				op1[1] <= 32'd53281;
				op2[0] <= {{24{1'b0}}, SRAM_U[0][15:8]} - 32'd128;
				op2[1] <= 32'd132251;
				green[0] <= Y_CSC[0] - result1;
				
				// Odd Color Space Converison
				
				// U FIR
				U_prime <= U_prime + result2;
			
				// V FIR
				V_prime <= V_prime + result3;
			end
			
			S_CC5: begin
				state <= S_CC6;
				//	Memory Reads
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET + 18'd2;
				SRAM_write_data <= { 
					(green[1][31] == 1) ? 8'd0 :           // If green[1] is negative, assign 8'd0
					(green[1][31:24] != 8'b0) ? 8'd255 :   // If the upper 8 bits of green[1] are non-zero, assign 8'b255
					 green[1][23:16],                      // Otherwise, assign the lower 8 bits of green[1]

					(blue[1][31] == 1) ? 8'd0 :            // If blue[1] is negative, assign 8'd0
					(blue[1][31:24] != 8'b0) ? 8'd255 :    // If the upper 8 bits of blue[1] are non-zero, assign 8'b255
					 blue[1][23:16]                        // Otherwise, assign the lower 8 bits of blue[1]
				};
				//SRAM_WRITE_DATA_TEMP[0] <= green[1];
				//SRAM_WRITE_DATA_TEMP[1] <= blue[1];
				SRAM_we_n <= 1'b0;
				// Memory Latches
				if(toggle == 1'b0) begin 
					SRAM_V[1] <= SRAM_read_data;
				end else begin 
					SRAM_V[0] <= SRAM_read_data;
				end
				// Even Color Space Converison 
				green[0] <= green[0] - result1;
				blue[0] <= Y_CSC[0] + result2;
				// Odd Color Space Converison
				op1[0] <= {{8{V_prime[31]}}, V_prime[31:8]} - 32'd128;
				op1[1] <= 32'd104595;
				op2[0] <= {{8{U_prime[31]}}, U_prime[31:8]} - 32'd128;
				op2[1] <= 32'd25624;
				op3[0] <= {{8{U_prime[31]}}, U_prime[31:8]} - 32'd128;
				op3[1] <= 32'd132251;
				// U FIR			
				// V FIR
				
				if(toggle == 1'b0) begin 
					SRAM_U[0] <= {SRAM_U[0][7:0], 8'b0};
					SRAM_V[0] <= {SRAM_V[0][7:0], 8'b0};
				end else begin 
					SRAM_U[1] <= {SRAM_U[1][7:0], 8'b0};
					SRAM_V[1] <= {SRAM_V[1][7:0], 8'b0};
				end
			end
			
			S_CC6: begin 
				state <= S_CC1;
				col_counter <= col_counter + 8'd1;
				//	Memory Reads
				SRAM_address <= (even_pixel_counter + 18'd4) >> 1;
				SRAM_we_n <= 1'b1;
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_Y[15:8]} - 32'd16; 
				op1[1] <= 32'd76284;
				// Odd Color Space Converison
				op2[0] <= {{8{V_prime[31]}}, V_prime[31:8]} - 32'd128;
				op2[1] <= 32'd53281;
				red[1] <= Y_CSC[1] +  result1;
				green [1] <= Y_CSC[1] - result2;
				blue[1] <= Y_CSC[1] + result3;
				// U FIR
				FIR_U[0] <= SRAM_U[1][15:8];    // Insert new data into the first element
           	FIR_U[1] <= FIR_U[0];       // Shift FIR_U[0] to FIR_U[1]
   			FIR_U[2] <= FIR_U[1];       // Shift FIR_U[1] to FIR_U[2]
				FIR_U[3] <= FIR_U[2];       // Shift FIR_U[2] to FIR_U[3]
				FIR_U[4] <= FIR_U[3];       // Shift FIR_U[3] to FIR_U[4]
            FIR_U[5] <= FIR_U[4];       // Shift FIR_U[4] to FIR_U[5]
				// V FIR
				FIR_V[0] <= SRAM_V[1][15:8];    // Insert new data into FIR_V[0]
            FIR_V[1] <= FIR_V[0];       // Shift FIR_V[0] to FIR_V[1]
            FIR_V[2] <= FIR_V[1];       // Shift FIR_V[1] to FIR_V[2]
            FIR_V[3] <= FIR_V[2];       // Shift FIR_V[2] to FIR_V[3]
         	FIR_V[4] <= FIR_V[3];       // Shift FIR_V[3] to FIR_V[4]
         	FIR_V[5] <= FIR_V[4];       // Shift FIR_V[4] to FIR_V[5]
				// toggle
				toggle <= ~toggle;
				// Lead out check
				write_address_counter <= write_address_counter + 18'd3;
				if(col_counter == 8'd155) begin 
					state <= S_LO1; 
				end

				if(even_pixel_counter == 74240) begin 
					state <= S_DONE;
				end else begin
					even_pixel_counter <= even_pixel_counter + 18'd2;
				end
			end
			
			
			S_LO1: begin 
				state <= S_LO2;
				//	Memory Writes
				//	Memory Reads
				if(toggle == 1'b0) begin 
					SRAM_address <= ((even_pixel_counter + 18'd8) >> 2) + U_OFFSET;
					SRAM_we_n <= 1'b1;
				end else begin 
					SRAM_address <= ((even_pixel_counter + 18'd2) >> 2) + U_OFFSET;
					SRAM_we_n <= 1'b1;
				end
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				Y_CSC[0] <= result1; // For pixel n
				
				// Odd Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_Y[7:0]} - 32'd16; // For pixel n + 1
				op1[1] <= 23'd76284;
				
				green[1] <= green[1] - result2; // for pixel n-1
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[0]} + {1'b0, FIR_U[5]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd21;
				
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[0]} + {1'b0, FIR_V[5]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd21;
				
			end
			
			S_LO2: begin 
				state <= S_LO3;
				//	Memory Writes
				//	Memory Reads
				if(toggle == 1'b0) begin 
					SRAM_address <= ((even_pixel_counter + 18'd8) >> 2) + V_OFFSET;
					SRAM_we_n <= 1'b1;
				end else begin 
					SRAM_address <=  ((even_pixel_counter + 18'd2) >> 2) + V_OFFSET;
					SRAM_we_n <= 1'b1;
				
				end
				// Memory Writes 
				// Memory Latches
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_V[0][15:8]} - 32'd128;
				op1[1] <= 32'd104595;
				
				// Odd Color Space Converison
				Y_CSC[1] <= result1; // For pixel n + 1
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[1]} + {1'b0, FIR_U[4]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd52;
				U_prime <= 32'd128 + result2;
			
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[1]} + {1'b0, FIR_V[4]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd52;
				V_prime <= 32'd128 + result3;
			end
		
			S_LO3: begin 
				state <= S_LO4;
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET;
				SRAM_write_data <= { 
					 (red[0][31] == 1) ? 8'd0 :            // If blue[0] is negative, assign 8'd0
					 (red[0][31:24] != 8'd0) ? 8'd255 :    // If the upper 8 bits of blue[0] are non-zero, assign 8'b255
					  red[0][23:16],                       // Otherwise, assign the lower 8 bits of blue[0]

					 (green[0][31] == 1) ? 8'd0 :             // If red[1] is negative, assign 8'd0
					 (green[0][31:24] != 8'd0) ? 8'd255 :     // If the upper 8 bits of red[1] are non-zero, assign 8'b255
					  green[0][23:16]                         // Otherwise, assign the lower 8 bits of red[1]
				};
				
				//SRAM_WRITE_DATA_TEMP[0] <= red[0];
				//SRAM_WRITE_DATA_TEMP[1] <= green[0];
				SRAM_we_n <= 1'b0;
				//	Memory Reads
				// Memory Latches
				SRAM_Y <= SRAM_read_data;
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, {SRAM_U[0][15:8]}} - 32'd128;
				op1[1] <= 32'd25624;
				red[0] <= Y_CSC[0] + result1;
				
				// Odd Color Space Converison
				
				// U FIR
				op2[0] <= {{23{1'b0}}, {1'b0, FIR_U[2]} + {1'b0, FIR_U[3]}}; // Adding 8 bit nums can result in up to 9 bits
				op2[1] <= 32'd159;
				U_prime <= U_prime - result2;
			
				// V FIR
				op3[0] <= {{23{1'b0}}, {1'b0, FIR_V[2]} + {1'b0, FIR_V[3]}}; // Adding 8 bit nums can result in up to 9 bits
				op3[1] <= 32'd159;
				V_prime <= V_prime - result3;
			end
			
			S_LO4: begin
				state <= S_LO5;
				//	Memory Reads
				// Memory Writes 
				SRAM_address <= write_address_counter + RGB_OFFSET + 18'd1;
				SRAM_write_data <= { 
					 (blue[0][31] == 1) ? 8'd0 :           // If green[1] is negative, assign 8'd0
					 (blue[0][31:24] != 8'd0) ? 8'd255 :   // If the upper 8 bits of green[1] are non-zero, assign 8'b255
					  blue[0][23:16],                      // Otherwise, assign the lower 8 bits of green[1]

					 (red[1][31] == 1) ? 8'd0 :            // If blue[1] is negative, assign 8'd0
					 (red[1][31:24] != 8'd0) ? 8'd255 :    // If the upper 8 bits of blue[1] are non-zero, assign 8'b255
					  red[1][23:16]                        // Otherwise, assign the lower 8 bits of blue[1]
				};
				//SRAM_WRITE_DATA_TEMP[0] <= blue[0];
				//SRAM_WRITE_DATA_TEMP[1] <= red[1];
				SRAM_we_n <= 1'b0;
				// Memory Latches
				if(toggle == 1'b0) begin 
					SRAM_U[1] <= SRAM_read_data;
				end else begin 
					SRAM_U[0] <= SRAM_read_data;
				end
				// Even Color Space Converison 
				op1[0] <= {{24{1'b0}}, SRAM_V[0][15:8]} - 32'd128;
				op1[1] <= 32'd53281;
				op2[0] <= {{24{1'b0}}, SRAM_U[0][15:8]} - 32'd128;
				op2[1] <= 32'd132251;
				green[0] <= Y_CSC[0] - result1;
				
				// Odd Color Space Converison
				
				// U FIR
				U_prime <= U_prime + result2;
			
				// V FIR
				V_prime <= V_prime + result3;
			end
			
			S_LO5: begin
				state <= S_LO6;
				//	Memory Reads
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET + 18'd2;
				SRAM_write_data <= { 
					(green[1][31] == 1) ? 8'd0 :           // If green[1] is negative, assign 8'd0
					(green[1][31:24] != 8'b0) ? 8'd255 :   // If the upper 8 bits of green[1] are non-zero, assign 8'b255
					 green[1][23:16],                      // Otherwise, assign the lower 8 bits of green[1]

					(blue[1][31] == 1) ? 8'd0 :            // If blue[1] is negative, assign 8'd0
					(blue[1][31:24] != 8'b0) ? 8'd255 :    // If the upper 8 bits of blue[1] are non-zero, assign 8'b255
					 blue[1][23:16]                        // Otherwise, assign the lower 8 bits of blue[1]
				};
				//SRAM_WRITE_DATA_TEMP[0] <= green[1];
				//SRAM_WRITE_DATA_TEMP[1] <= blue[1];
				SRAM_we_n <= 1'b0;
				// Memory Latches
				if(toggle == 1'b0) begin 
					SRAM_V[1] <= SRAM_read_data;
				end else begin 
					SRAM_V[0] <= SRAM_read_data;
				end
				// Even Color Space Converison 
				green[0] <= green[0] - result1;
				blue[0] <= Y_CSC[0] + result2;
				// Odd Color Space Converison
				op1[0] <= {{8{V_prime[31]}}, V_prime[31:8]} - 32'd128;
				op1[1] <= 32'd104595;
				op2[0] <= {{8{U_prime[31]}}, U_prime[31:8]} - 32'd128;
				op2[1] <= 32'd25624;
				op3[0] <= {{8{U_prime[31]}}, U_prime[31:8]} - 32'd128;
				op3[1] <= 32'd132251;
				// U FIR			
				// V FIR
				
				if(toggle == 1'b0) begin 
					SRAM_U[0] <= {SRAM_U[0][7:0], 8'b0};
					SRAM_V[0] <= {SRAM_V[0][7:0], 8'b0};
				end else begin 
					SRAM_U[1] <= {SRAM_U[1][7:0], 8'b0};
					SRAM_V[1] <= {SRAM_V[1][7:0], 8'b0};
				end
			end
			
			S_LO6: begin 
				state <= S_LO1;
				//	Memory Reads, NEXT pixel Y
				SRAM_address <= (even_pixel_counter + 18'd4) >> 1;
				SRAM_we_n <= 1'b1;
				
				// Memory Writes 
				// Memory Latches
				
				// Even Color Space Converison for NEXT pixel
				op1[0] <= {{24{1'b0}}, SRAM_Y[15:8]} - 32'd16; 
				op1[1] <= 32'd76284;
				
				// Odd Color Space Converison
				op2[0] <= {{8{V_prime[31]}}, V_prime[31:8]} - 32'd128;
				op2[1] <= 32'd53281;
				red[1] <= Y_CSC[1] +  result1;
				green [1] <= Y_CSC[1] - result2;
				blue[1] <= Y_CSC[1] + result3;
				
				// Seting up FIRs for the NEXT pixel 
				// U FIR
				FIR_U[0] <= FIR_U[0];       // Insert new data into the first element
           	FIR_U[1] <= FIR_U[0];       // Shift FIR_U[0] to FIR_U[1]
   			FIR_U[2] <= FIR_U[1];       // Shift FIR_U[1] to FIR_U[2]
				FIR_U[3] <= FIR_U[2];       // Shift FIR_U[2] to FIR_U[3]
				FIR_U[4] <= FIR_U[3];       // Shift FIR_U[3] to FIR_U[4]
            FIR_U[5] <= FIR_U[4];       // Shift FIR_U[4] to FIR_U[5]
				// V FIR
				FIR_V[0] <= FIR_V[0];    // Insert new data into FIR_V[0]
            FIR_V[1] <= FIR_V[0];       // Shift FIR_V[0] to FIR_V[1]
            FIR_V[2] <= FIR_V[1];       // Shift FIR_V[1] to FIR_V[2]
            FIR_V[3] <= FIR_V[2];       // Shift FIR_V[2] to FIR_V[3]
         	FIR_V[4] <= FIR_V[3];       // Shift FIR_V[3] to FIR_V[4]
         	FIR_V[5] <= FIR_V[4];       // Shift FIR_V[4] to FIR_V[5]
				
				// toggle
				toggle <= ~toggle;
				
				
				write_address_counter <= write_address_counter + 18'd3;
				
				// Lead out check, if we are on the last pixel in that row
				if(col_counter == 8'd159) begin 
					state <= S_LO7;
					col_counter <= 8'd0;
				end else begin 
					col_counter <= col_counter + 8'd1;
				end
				
				if(even_pixel_counter < 18'd76798) begin 
					even_pixel_counter <= even_pixel_counter + 18'd2;
				end
				
			end
			
			S_LO7: begin 
				state  <= S_LO8;
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET;
				SRAM_write_data <= { 
					 (red[0][31] == 1) ? 8'd0 :            // If blue[0] is negative, assign 8'd0
					 (red[0][31:24] != 8'd0) ? 8'd255 :    // If the upper 8 bits of blue[0] are non-zero, assign 8'b255
					  red[0][23:16],                       // Otherwise, assign the lower 8 bits of blue[0]

					 (green[0][31] == 1) ? 8'd0 :             // If red[1] is negative, assign 8'd0
					 (green[0][31:24] != 8'd0) ? 8'd255 :     // If the upper 8 bits of red[1] are non-zero, assign 8'b255
					  green[0][23:16]                         // Otherwise, assign the lower 8 bits of red[1]
				};
				
				SRAM_we_n <= 1'b0;
			
				green [1] <= green[1] - result2;
			end
			
			S_LO8: begin 
				state  <= S_LO9;
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET + 18'd1;
				SRAM_write_data <= { 
					 (blue[0][31] == 1) ? 8'd0 :           // If green[1] is negative, assign 8'd0
					 (blue[0][31:24] != 8'd0) ? 8'd255 :   // If the upper 8 bits of green[1] are non-zero, assign 8'b255
					  blue[0][23:16],                      // Otherwise, assign the lower 8 bits of green[1]

					 (red[1][31] == 1) ? 8'd0 :            // If blue[1] is negative, assign 8'd0
					 (red[1][31:24] != 8'd0) ? 8'd255 :    // If the upper 8 bits of blue[1] are non-zero, assign 8'b255
					  red[1][23:16]                        // Otherwise, assign the lower 8 bits of blue[1]
				};
				SRAM_we_n <= 1'b0;
			end
			
			S_LO9: begin 
				state  <= S_LI1;
				write_address_counter <= write_address_counter + 18'd3;
				// Memory Writes
				SRAM_address <= write_address_counter + RGB_OFFSET + 18'd2;
				SRAM_write_data <= { 
					(green[1][31] == 1) ? 8'd0 :           // If green[1] is negative, assign 8'd0
					(green[1][31:24] != 8'b0) ? 8'd255 :   // If the upper 8 bits of green[1] are non-zero, assign 8'b255
					 green[1][23:16],                      // Otherwise, assign the lower 8 bits of green[1]

					(blue[1][31] == 1) ? 8'd0 :            // If blue[1] is negative, assign 8'd0
					(blue[1][31:24] != 8'b0) ? 8'd255 :    // If the upper 8 bits of blue[1] are non-zero, assign 8'b255
					 blue[1][23:16]                        // Otherwise, assign the lower 8 bits of blue[1]
				};
				SRAM_we_n <= 1'b0;
				if(even_pixel_counter == 18'd76798) begin 
					state <= S_DONE;
				end
			end

			S_DONE: begin 
				done <= 1'b1;
				if(ena == 1'b0) begin 
					state <= S_IDLE;
				end
			end
		endcase 
	end
end



logic [63:0] temp_result1;
logic [63:0] temp_result2;
logic [63:0] temp_result3;

always_comb begin
	temp_result1 = 64'd0;
	temp_result2 = 64'd0;
	temp_result3 = 64'd0;
	result1 = 32'd0;	
	result2 = 32'd0;	
	result3 = 32'd0;	
	if (~resetn) begin 
      // Reset results to 0
      result1 = 32'd0;
      result2 = 32'd0;
      result3 = 32'd0;
   end else if (state != S_IDLE) begin 
      // Store the full multiplication results in temporary wires
      temp_result1 = op1[0] * op1[1];
      temp_result2 = op2[0] * op2[1];
      temp_result3 = op3[0] * op3[1];

      // Assign only the lower 32 bits of each temp result to the final 32-bit results
      result1 = temp_result1[31:0];
      result2 = temp_result2[31:0];
      result3 = temp_result3[31:0];
   end
end

endmodule
