module milestone2 (
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


parameter [17:0] Y_OFFSET = 18'd76800; 
parameter [17:0] U_OFFSET = 18'd153600;
parameter [17:0] V_OFFSET = 18'd192000;

parameter [17:0] Y_OFFSET_write = 18'd0; 
parameter [17:0] U_OFFSET_write = 18'd38400;
parameter [17:0] V_OFFSET_write = 18'd57600;

// State Def
typedef enum logic [2:0] {
	S_IDLE,
	S_LI1,
	S_LI2,
	S_CC1, 
	S_CC2, 
	S_LO1, 
	S_LO2, 
	S_DONE
} state_type;


state_type state;


// Tracks the current element in the matrix 
logic [6:0] index_count; 
logic [6:0] index_count_delay1; // Delay index count as the SRAM has a 2 clk latency 


//------Write to SRAM-----
// Track the row and col of where you are writeing
logic [5:0] col_block_write;
logic [4:0] row_block_write;
logic [1:0] block_state_write; // Y, U or V

// Hold one value to be written while we get the next one
logic [7:0] SRAM_data_write_buffer_reg;
logic [7:0] SRAM_data_write_buffer_next;

// write to sram
logic [17:0] SRAM_address_write;
logic [15:0] SRAM_write_data_write;
logic SRAM_we_n_write;
logic [15:0] SRAM_read_data_write;

// read from embedded ram
logic [6:0] address_sram_read;
logic [31:0] read_data_sram_read;


//----------Matrix Mult Stuff-------------
// mod 8 counter
logic [2:0] column_count;

// mod 3 counter 
logic [1:0] state_count;
logic [1:0] state_count_dealy;

// second mod 8 counter
logic [2:0] row_count;

// all calulations are done just need to write last two values
logic lead_out_ena;
logic lead_out_ena_delay;
logic lead_out_ena_delay2;

// three mac_regs to hold the partial sums 
logic [31:0] mac_reg [2:0];
logic [31:0] mac_next [2:0];

// two registers to hold the finished values while we wait to write them
logic [31:0] result_reg [1:0];
logic [31:0] result_next [1:0];

// counter to store write memory address
logic [6:0] write_address_count_reg;
logic [6:0] write_address_count_next;

// Read form one matrix 
logic [6:0] address_read_mult;
logic [31:0] data_read_mult;

// Read the c matrix 
logic [6:0] address_c_mult [2:0];
logic [31:0] data_read_C_mult [2:0];

// Write the result
logic [6:0] address_write_mult;
logic [31:0] data_write_mult;
logic write_enable_mult;


// For multipliers 
logic [31:0] op1 [1:0];
logic [31:0] op2 [1:0];
logic [31:0] op3 [1:0];
logic [31:0] result1;
logic [31:0] result2;
logic [31:0] result3;
logic [63:0] temp_result1;
logic [63:0] temp_result2;
logic [63:0] temp_result3;



//-------------Memory stuff-------------
logic [6:0] address_a [2:0];
logic [6:0] address_b [2:0];
logic [31:0] write_data_a [2:0];
logic [31:0] write_data_b [2:0];
logic write_enable_a [2:0];
logic write_enable_b [2:0];
logic [31:0] read_data_a [2:0];
logic [31:0] read_data_b [2:0];

dual_port_RAM2 RAM_inst0 (
	.address_a ( address_a[0] ),
	.address_b ( address_b[0] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[0] ),
	.data_b ( write_data_b[0] ),
	.wren_a ( write_enable_a[0] ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
);

dual_port_RAM1 RAM_inst1 (
	.address_a ( address_a[1] ),
	.address_b ( address_b[1] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[1] ),
	.data_b ( write_data_b[1] ),
	.wren_a ( write_enable_a[1] ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
);

dual_port_RAM2 RAM_inst2 (
	.address_a ( address_a[2] ),
	.address_b ( address_b[2] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[2] ),
	.data_b ( write_data_b[2] ),
	.wren_a ( write_enable_a[2] ),
	.wren_b ( write_enable_b[2] ),
	.q_a ( read_data_a[2] ),
	.q_b ( read_data_b[2] )
);


logic m3_ena; 
logic m3_resetn; 
logic [17:0] m3_SRAM_address;
logic [15:0] m3_SRAM_write_data;
logic m3_SRAM_we_n;
logic [15:0] m3_SRAM_read_data;
logic m3_done;
assign m3_resetn = resetn;

logic m3_write_en_decode;
logic [5:0] m3_write_address_decode;
logic [31:0] m3_write_data_decode;
logic m3_wr_en;
assign m3_wr_en = state == S_CC1 ? 1'b1 : 1'b0;

milestone3 u_milestone3 (
        .CLOCK_50_I(CLOCK_50_I),               // 50 MHz clock
        .resetn(m3_resetn),                       // async reset
        .ena(m3_ena),                             // enable module

        .SRAM_address(m3_SRAM_address),           // SRAM address output
        .SRAM_write_data(m3_SRAM_write_data),     // SRAM write data output
        .SRAM_we_n(m3_SRAM_we_n),                 // SRAM write enable output
        .SRAM_read_data(m3_SRAM_read_data),        // SRAM read data input
		  .done(m3_done), 
		  .write_en_decode(m3_write_en_decode), 
		  .write_address_decode(m3_write_address_decode),
		  .write_data_decode(m3_write_data_decode),
		  .wr_en(m3_wr_en)
);



always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin 
        // Reset all signals to their default values
		  
		  state <= S_IDLE;
        done <= 1'b0;
        // SRAM control and data signals
		  SRAM_data_write_buffer_reg <= 8'd0;
		  
		  index_count <= 7'd0;
		  index_count_delay1 <= 7'd0;
		  column_count <= 3'd0;
		  
		  
		  col_block_write <= 5'd0;
		  row_block_write <= 4'd0;
		  block_state_write <= 2'd0;
		  
			state_count <= 2'd0;
			state_count_dealy <= 2'd3;
			row_count <= 3'b0;

			// reset three mac_regs to hold the partial sums
			mac_reg[0] <= 32'b0;
			mac_reg[1] <= 32'b0;
			mac_reg[2] <= 32'b0;

			// reset three registers to hold the finished values while waiting to write
			result_reg[0] <= 32'd0;
			result_reg[1] <= 32'd0;
			
			write_address_count_reg <= 7'd0;
		
		
			// reset done 
			//done <= 1'b0;
			
			lead_out_ena <= 1'b0;
			lead_out_ena_delay <= 1'b0;
			lead_out_ena_delay2 <= 1'b0;
			
			m3_ena <= 1'b0;
		  
		  
		  
	end else begin
	
		index_count_delay1 <= index_count;
		
		state_count_dealy <= state_count;
		
		mac_reg[0] <= mac_next[0];
		mac_reg[1] <= mac_next[1];
		mac_reg[2] <= mac_next[2];
		
		result_reg[0] = result_next[0];
		result_reg[1] = result_next[1];
		
		write_address_count_reg <= write_address_count_next;
		
		lead_out_ena_delay <= lead_out_ena;
		lead_out_ena_delay2 <= lead_out_ena_delay;
		
		SRAM_data_write_buffer_reg <= SRAM_data_write_buffer_next;

		case(state) 
		
			S_IDLE: begin
				state <= S_IDLE;
				if(ena == 1'b1) begin 
					state <= S_LI1;
					m3_ena <= 1'b1;
				end
			end
			
			S_LI1: begin
				state <= S_LI1;
				m3_ena <= 1'b0;
				if(m3_done == 1'b1) begin 
					state <= S_LI2;
				end 
			end
			
			S_LI2: begin
				state <= S_LI2;
				
				// Mult of S prime times C
				if (column_count != 3'd7) begin 
					column_count <= column_count + 3'd1;
				end else begin 
					column_count <= 3'b0;
					if (state_count != 2'd2) begin 
						state_count <= state_count + 2'd1;
					end else begin 
						state_count <= 2'd0;
						if(row_count != 3'd7) begin 
							row_count <= row_count + 3'd1;
						end else begin 
							row_count <= 3'd0;
							lead_out_ena <= 1'b1;
						end
					end
				end
				
				// Reset The registers for the SRAM reads and the mult
				if(lead_out_ena_delay2) begin
					state <= S_CC1;
					m3_ena <= 1'b1;
					column_count <= 3'd0;
					state_count <= 2'd0;
					row_count <= 3'd0;
					index_count <= 7'd0;
					lead_out_ena <= 1'b0;
					lead_out_ena_delay <= 1'b0;
					lead_out_ena_delay2 <= 1'b0;
					write_address_count_reg <= 7'd0;
				end
			end
			
			S_CC1: begin
				state <= S_CC1;
				m3_ena <= 1'b0;
				// Mult of Transpose times Temp
				if (column_count != 3'd7) begin 
					column_count <= column_count + 3'd1;
				end else begin 
					column_count <= 3'b0;
					if (state_count != 2'd2) begin 
						state_count <= state_count + 2'd1;
					end else begin 
						state_count <= 2'd0;
						if(row_count != 3'd7) begin 
							row_count <= row_count + 3'd1;
						end else begin 
							row_count <= 3'd0;
							lead_out_ena <= 1'b1;
						end
					end
				end
				
				// Reading form SRAM
				if(index_count == 7'd64) begin
					// Nothing
				end else begin 
					index_count <= index_count + 7'd1;
				end
				
				if(lead_out_ena_delay2) begin
					state <= S_CC2;
					column_count <= 3'd0;
					state_count <= 2'd0;
					row_count <= 3'd0;
					index_count <= 7'd0;
					lead_out_ena <= 1'b0;
					lead_out_ena_delay <= 1'b0;
					lead_out_ena_delay2 <= 1'b0;
					write_address_count_reg <= 7'd0;
				end
			end
			
			
			S_CC2: begin
				state <= S_CC2;
				
				// Mult of S prime times C
				if (column_count != 3'd7) begin 
					column_count <= column_count + 3'd1;
				end else begin 
					column_count <= 3'b0;
					if (state_count != 2'd2) begin 
						state_count <= state_count + 2'd1;
					end else begin 
						state_count <= 2'd0;
						if(row_count != 3'd7) begin 
							row_count <= row_count + 3'd1;
						end else begin 
							row_count <= 3'd0;
							lead_out_ena <= 1'b1;
						end
					end
				end
				
				// Write to SRAM
				if(index_count == 7'd64) begin
					// Nothing
				end else begin 
					index_count <= index_count + 7'd1;
				end
				
				// Reset The registers for the SRAM reads and the mult
				if(lead_out_ena_delay2) begin
					state <= S_CC1;
					m3_ena <= 1'b1;
					column_count <= 3'd0;
					state_count <= 2'd0;
					row_count <= 3'd0;
					index_count <= 7'd0;
					lead_out_ena <= 1'b0;
					lead_out_ena_delay <= 1'b0;
					lead_out_ena_delay2 <= 1'b0;
					write_address_count_reg <= 7'd0;

					if(block_state_write == 2'b0) begin
						if (col_block_write != 6'd39 ) begin 
							col_block_write <= col_block_write + 5'd1;
						end else begin 
							col_block_write <= 6'd0;
							if(row_block_write != 5'd29) begin 
								row_block_write <= row_block_write + 4'd1;
							end else begin 
								row_block_write <= 5'd0;
								block_state_write <= block_state_write + 2'd1;
							end
						end
					end else if (block_state_write == 2'd1) begin
						if (col_block_write != 6'd19 ) begin 
							col_block_write <= col_block_write + 5'd1;
						end else begin 
							col_block_write <= 6'd0;
							if(row_block_write != 6'd29) begin 
								row_block_write <= row_block_write + 4'd1;
							end else begin 
								row_block_write <= 5'd0;
								block_state_write <= block_state_write + 2'd1;
							end
						end
					end else if (block_state_write == 2'd2) begin
						if (col_block_write != 6'd19) begin 
							col_block_write <= col_block_write + 5'd1;
						end else begin 
							col_block_write <= 2'd0;
							if(row_block_write != 5'd29) begin 
								row_block_write <= row_block_write + 4'd1;
							end else begin 
							end
						end
					end
					if(block_state_write == 2'd2 && col_block_write == 6'd18 && row_block_write == 5'd29)begin 
						//col_block_write <= col_block_write + 5'd1;
						m3_ena <= 1'b0;
						state <= S_LO1;
					end
				end	
			end		
			
			S_LO1: begin
				state <= S_LO1;
				
				// Mult of Transpose times Temp
				if (column_count != 3'd7) begin 
					column_count <= column_count + 3'd1;
				end else begin 
					column_count <= 3'b0;
					if (state_count != 2'd2) begin 
						state_count <= state_count + 2'd1;
					end else begin 
						state_count <= 2'd0;
						if(row_count != 3'd7) begin 
							row_count <= row_count + 3'd1;
						end else begin 
							row_count <= 3'd0;
							lead_out_ena <= 1'b1;
						end
					end
				end
				
				if(lead_out_ena_delay2) begin
					state <= S_LO2;
					column_count <= 3'd0;
					state_count <= 2'd0;
					row_count <= 3'd0;
					index_count <= 7'd0;
					lead_out_ena <= 1'b0;
					lead_out_ena_delay <= 1'b0;
					lead_out_ena_delay2 <= 1'b0;
					write_address_count_reg <= 7'd0;
				end
			end
			
			
			S_LO2: begin
				state <= S_LO2;
				
				// Write to SRAM
				if(index_count == 7'd64) begin 
					state <= S_DONE;
				end else begin 
					index_count <= index_count + 7'd1;
				end
			end
			
			
			S_DONE: begin 
				done <= 1'b1;
			end
		endcase
	end
end // always




always_comb begin 
	case(state)
		S_IDLE: begin 
		 address_a[0] = 7'b0;
		 address_a[1] = 7'b0;
		 address_a[2] = 7'b0;

		 address_b[0] = 7'b0;
		 address_b[1] = 7'b0;
		 address_b[2] = 7'b0;

		 write_data_a[0] = 32'b0;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = 32'b0;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] = 1'b0;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = 1'b0;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = 32'b0;
		 data_read_mult  = 32'b0;
		 data_read_C_mult[0] = 32'b0;
		 data_read_C_mult[1] = 32'b0;
		end
		
		S_LI1: begin 
		 address_a[0] = m3_write_address_decode;
		 address_a[1] = 3'b0;
		 address_a[2] = 3'b0;

		 address_b[0] = 3'b0;
		 address_b[1] = 3'b0;
		 address_b[2] = 3'b0;

		 write_data_a[0] = m3_write_data_decode;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = 32'b0;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] =  m3_write_en_decode;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = 1'b0;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = 32'b0;
		 data_read_mult  = 32'b0;
		 data_read_C_mult[0] = 32'b0;
		 data_read_C_mult[1] = 32'b0;
		end
		
		S_LI2: begin 
		 address_a[0] = 7'd0;
		 address_a[1] = address_c_mult[0];
		 address_a[2] = address_write_mult;

		 address_b[0] = address_read_mult;
		 address_b[1] = address_c_mult[1];
		 address_b[2] = 7'b0;

		 write_data_a[0] = 32'd0;;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = data_write_mult;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] = 1'b0;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = write_enable_mult;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = 32'b0;
		 data_read_mult  = read_data_b[0];
		 data_read_C_mult[0] = read_data_a[1];
		 data_read_C_mult[1] = read_data_b[1];
		end
		
		S_CC1: begin 
		 address_a[0] = m3_write_address_decode;
		 address_a[1] = address_c_mult[0];
		 address_a[2] = address_write_mult;

		 address_b[0] = 7'd0;;
		 address_b[1] = address_c_mult[1];
		 address_b[2] = address_read_mult;

		 write_data_a[0] = m3_write_data_decode;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = data_write_mult;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] = m3_write_en_decode;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = write_enable_mult;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = 32'b0;
		 data_read_mult  = read_data_b[2];
		 data_read_C_mult[0] = read_data_a[1];
		 data_read_C_mult[1] = read_data_b[1];
		end
		
		S_CC2: begin 
		 address_a[0] = 7'd0;
		 address_a[1] = address_c_mult[0];
		 address_a[2] = address_write_mult;

		 address_b[0] = address_read_mult;
		 address_b[1] = address_c_mult[1];
		 address_b[2] = address_sram_read;

		 write_data_a[0] = 32'd0;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = data_write_mult;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] = 1'b0;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = write_enable_mult;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = read_data_b[2];
		 data_read_mult  = read_data_b[0];
		 data_read_C_mult[0] = read_data_a[1];
		 data_read_C_mult[1] = read_data_b[1];
		end
		
		S_LO1: begin 
		 address_a[0] = 7'd0;
		 address_a[1] = address_c_mult[0];
		 address_a[2] = address_write_mult;

		 address_b[0] = 7'd0;;
		 address_b[1] = address_c_mult[1];
		 address_b[2] = address_read_mult;

		 write_data_a[0] = 32'd0;;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = data_write_mult;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] = 1'b0;;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = write_enable_mult;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = 32'b0;
		 data_read_mult  = read_data_b[2];
		 data_read_C_mult[0] = read_data_a[1];
		 data_read_C_mult[1] = read_data_b[1];
		end
		
		
		S_LO2: begin // Write to SRAM only
		 address_a[0] = 7'd0;
		 address_a[1] = address_c_mult[0];
		 address_a[2] = address_write_mult;

		 address_b[0] = 7'd0;;
		 address_b[1] = address_c_mult[1];
		 address_b[2] = address_sram_read;

		 write_data_a[0] = 32'd0;;
		 write_data_a[1] = 32'b0;
		 write_data_a[2] = data_write_mult;

		 write_data_b[0] = 32'b0;
		 write_data_b[1] = 32'b0;
		 write_data_b[2] = 32'b0;

		 write_enable_a[0] = 1'b0;;
		 write_enable_a[1] = 1'b0;
		 write_enable_a[2] = write_enable_mult;

		 write_enable_b[0] = 1'b0;
		 write_enable_b[1] = 1'b0;
		 write_enable_b[2] = 1'b0;
		 
		 read_data_sram_read = read_data_b[2];
		 data_read_mult  = read_data_b[2];
		 data_read_C_mult[0] = read_data_a[1];
		 data_read_C_mult[1] = read_data_b[1];
		end
		
		
		default: begin 
			address_a[0] = 7'b0;
			address_a[1] = 7'b0;
			address_a[2] = 7'b0;

			 address_b[0] = 7'b0;
			 address_b[1] = 7'b0;
			 address_b[2] = 7'b0;

			 write_data_a[0] = 32'b0;
			 write_data_a[1] = 32'b0;
			 write_data_a[2] = 32'b0;

			 write_data_b[0] = 32'b0;
			 write_data_b[1] = 32'b0;
			 write_data_b[2] = 32'b0;

			 write_enable_a[0] = 1'b0;
			 write_enable_a[1] = 1'b0;
			 write_enable_a[2] = 1'b0;

			 write_enable_b[0] = 1'b0;
			 write_enable_b[1] = 1'b0;
			 write_enable_b[2] = 1'b0;
			 
			 read_data_sram_read = 32'b0;
			 data_read_mult  = 32'b0;
			 data_read_C_mult[0] = 32'b0;
			 data_read_C_mult[1] = 32'b0;
		end
	endcase
end

always_comb begin 
	case(state)
		S_LI1: begin 
			SRAM_address = m3_SRAM_address;
			SRAM_write_data = 16'd0;
			SRAM_we_n = 1'd1;
			m3_SRAM_read_data = SRAM_read_data;
		end
		
		S_LI2: begin 
			SRAM_address = 18'd0;
			SRAM_write_data = 16'd0;
			SRAM_we_n = 1'd1;
			m3_SRAM_read_data = 16'd0;
		end
		
		S_CC1: begin 
			SRAM_address = m3_SRAM_address;
			SRAM_write_data = 16'd0;
			SRAM_we_n = 1'd1;
			m3_SRAM_read_data = SRAM_read_data;
		end
		
		S_CC2: begin 
			SRAM_address = SRAM_address_write;
			SRAM_write_data = SRAM_write_data_write;
			SRAM_we_n = SRAM_we_n_write;
			m3_SRAM_read_data = 16'd0;
		end
		
		S_LO1: begin 
			SRAM_address = 18'd0;
			SRAM_write_data = 16'd0;
			SRAM_we_n = 1'd1;
			m3_SRAM_read_data = 16'd0;
		end
		
		S_LO2: begin 
			SRAM_address = SRAM_address_write;
			SRAM_write_data = SRAM_write_data_write;
			SRAM_we_n = SRAM_we_n_write;
			m3_SRAM_read_data = 16'd0;
		end
		
		default: begin 
			SRAM_address = 18'd0;
			SRAM_write_data = 16'd0;
			SRAM_we_n = 1'd1;
			m3_SRAM_read_data = 16'd0;
		end
	endcase
end


//-----Write to SRAM--------
// Write to SRAM
always_comb begin 
	SRAM_address_write = 18'd0;
	SRAM_we_n_write <= 1'b1;
	if((state == S_CC2 || state == S_LO2) && index_count_delay1[0]) begin 
		SRAM_we_n_write <= 1'b0;
		case(block_state_write) 
			2'd0: SRAM_address_write = {{3{1'b0}}, row_block_write, index_count_delay1[5:3], {7{1'b0}}} + {{5{1'b0}}, row_block_write, index_count_delay1[5:3], {5{1'b0}}} + {{10{1'b0}}, col_block_write, index_count_delay1[2:1]} + Y_OFFSET_write;
			2'd1: SRAM_address_write = {{4{1'b0}}, row_block_write, index_count_delay1[5:3], {6{1'b0}}} + {{6{1'b0}}, row_block_write, index_count_delay1[5:3], {4{1'b0}}} + {{10{1'b0}}, col_block_write, index_count_delay1[2:1]} + U_OFFSET_write;		
			2'd2: SRAM_address_write = {{4{1'b0}}, row_block_write, index_count_delay1[5:3], {6{1'b0}}} + {{6{1'b0}}, row_block_write, index_count_delay1[5:3], {4{1'b0}}} + {{10{1'b0}}, col_block_write, index_count_delay1[2:1]} + V_OFFSET_write;
		endcase
	end
end


// Read from embedded ram
always_comb begin 
	address_sram_read = 7'd0;
	SRAM_write_data_write = 16'd0;
	SRAM_data_write_buffer_next = SRAM_data_write_buffer_reg;
	if((state == S_CC2 || state == S_LO2)) begin 
		if(index_count < 7'd65) begin 
			address_sram_read = {1'b1, index_count[2:0], index_count[5:3]};
			if(index_count[0]) begin 
				SRAM_data_write_buffer_next = (read_data_sram_read[31] == 1) ? 8'd0 : (read_data_sram_read[31:8] != 8'd0) ? 8'd255 : read_data_sram_read[7:0]; 
			end else begin 
				SRAM_write_data_write = {SRAM_data_write_buffer_reg, (read_data_sram_read[31] == 1) ? 8'd0 : (read_data_sram_read[31:8] != 24'd0) ? 8'd255 :read_data_sram_read[7:0]};
			end	
		end else begin 
			address_sram_read = 7'd0;
		end
	end
end





//---------mult-------------
always_comb begin 
	address_read_mult = 7'd0;
	address_c_mult[0] = 7'd0;
	address_c_mult[1] = 7'd0;
	if(state == S_CC2 || state == S_LI2) begin 
		case(state_count) 
			3'd0: begin 
				address_read_mult = {1'b0, row_count, column_count};
				address_c_mult[0] = {2'b00, column_count, 2'b00};
				address_c_mult[1] = {2'b00, column_count, 2'b01};
			end
			
			3'd1: begin 
				address_read_mult = {1'b0, row_count, column_count};
				address_c_mult[0] = {2'b00, column_count, 2'b01};
				address_c_mult[1] = {2'b00, column_count, 2'b10};
			end
			
			3'd2: begin 
				address_read_mult = {1'b0, row_count, column_count};
				address_c_mult[0] = {2'b00, column_count, 2'b11};
				address_c_mult[1] = 7'd0;
			end
		endcase
	end else if (state == S_CC1 || state == S_LO1) begin 
		case(state_count) 
			3'd0: begin 
				address_read_mult = {1'b0, column_count, row_count};
				address_c_mult[0] = {2'b00, column_count, 2'b00};
				address_c_mult[1] = {2'b00, column_count, 2'b01};
			end
			
			3'd1: begin 
				address_read_mult = {1'b0, column_count, row_count};
				address_c_mult[0] = {2'b00, column_count, 2'b01};
				address_c_mult[1] = {2'b00, column_count, 2'b10};
			end
			
			3'd2: begin 
				address_read_mult = {1'b0, column_count, row_count};
				address_c_mult[0] = {2'b00, column_count, 2'b11};
				address_c_mult[1] = 7'd0;
			end
		endcase
	end 
end


always_comb begin
	case(state_count_dealy)
		3'd0: begin 
			op1[0] = data_read_mult;
			op1[1] = {{16{data_read_C_mult[0][31]}}, data_read_C_mult[0][31:16]};
			
			op2[0] = data_read_mult;
			op2[1] = {{16{data_read_C_mult[0][15]}}, data_read_C_mult[0][15:0]};
			
			op3[0] = data_read_mult;
			op3[1] = {{16{data_read_C_mult[1][31]}}, data_read_C_mult[1][31:16]};
		end
		
		3'd1: begin 
			op1[0] = data_read_mult;
			op1[1] = {{16{data_read_C_mult[0][15]}}, data_read_C_mult[0][15:0]};
			
			op2[0] = data_read_mult;
			op2[1] = {{16{data_read_C_mult[1][31]}}, data_read_C_mult[1][31:16]};
			
			op3[0] = data_read_mult;
			op3[1] = {{16{data_read_C_mult[1][15]}}, data_read_C_mult[1][15:0]};
		end
		
		3'd2: begin 
			op1[0] = data_read_mult;
			op1[1] = {{16{data_read_C_mult[0][31]}}, data_read_C_mult[0][31:16]};
			
			op2[0] = data_read_mult;
			op2[1] = {{16{data_read_C_mult[0][15]}}, data_read_C_mult[0][15:0]};
			
			op3[0] = 32'd0;
			op3[1] = 32'd0;
		end
		
		default: begin 
			op1[0] = 32'd0;
			op1[1] = 32'd0;
			op2[0] = 32'd0;
			op2[1] = 32'd0;
			op3[0] = 32'd0;
			op3[1] = 32'd0;
		end
	endcase
end


always_comb begin
	temp_result1 = 64'd0;
	temp_result2 = 64'd0;
	temp_result3 = 64'd0;
	result1 = 32'd0;	
	result2 = 32'd0;	
	result3 = 32'd0;	
	if (~resetn) begin 
      // Reset result_regs to 0
      result1 = 32'd0;
      result2 = 32'd0;
      result3 = 32'd0;
   end else begin
      // Store the full multiplication result_regs in temporary wires
      temp_result1 = op1[0] * op1[1];
      temp_result2 = op2[0] * op2[1];
      temp_result3 = op3[0] * op3[1];

      // Assign only the lower 32 bits of each temp result_reg to the final 32-bit result_regs
      result1 = temp_result1[31:0];
      result2 = temp_result2[31:0];
      result3 = temp_result3[31:0];
   end
end


always_comb begin
	mac_next[0] = mac_reg[0];
	mac_next[1] = mac_reg[1];
	mac_next[2] = mac_reg[2];
	if(~lead_out_ena_delay) begin 
		if(column_count == 1'b1) begin 
			mac_next[0] = result1;
			mac_next[1] = result2;
			mac_next[2] = result3;
		end else begin
			mac_next[0] = mac_reg[0] + result1;
			mac_next[1] = mac_reg[1] + result2;
			mac_next[2] = mac_reg[2] + result3;
		end
	end
end


always_comb begin
	if(column_count == 1'b1) begin 
		result_next[0] = mac_reg[1];
		result_next[1] = mac_reg[2];
	end else begin
		result_next[0] = result_reg[0];
		result_next[1] = result_reg[1];
	end
end


always_comb begin 
	write_enable_mult = 1'b0;
	write_address_count_next = write_address_count_reg;
	data_write_mult = 32'd0;

	if(state == S_CC2 || state == S_LI2) begin 
		address_write_mult = {1'b0, write_address_count_reg[5:0]};
	end else if (state == S_CC1 || state == S_LO1) begin 
		address_write_mult = {1'b1, write_address_count_reg[5:0]};
	end else begin 
		address_write_mult = 7'd0;
	end

	if(((column_count > 3'd0 &&  column_count < 3'd3 && state_count == 2'd0) || (column_count > 3'd0 &&  column_count < 3'd4 && (state_count == 2'd1 || state_count == 2'd2))) && (row_count > 3'b0 || state_count > 3'b0 || lead_out_ena_delay) && write_address_count_reg != 7'd64) begin 
		 write_enable_mult = 1'b1;
		 write_address_count_next = write_address_count_reg + 7'd1;
		 
		 if(state == S_CC2 || state == S_LI2) begin 
			case(column_count)
				3'd1: data_write_mult = {{8{mac_reg[0][31]}}, mac_reg[0][31:8]};  // Apply Shift 
				3'd2: data_write_mult = {{8{result_reg[0][31]}}, result_reg[0][31:8]};
				3'd3: data_write_mult = {{8{result_reg[1][31]}}, result_reg[1][31:8]};
			endcase	
		 end else if (state == S_CC1 || state == S_LO1) begin 
			case(column_count)
				3'd1: data_write_mult = {{16{mac_reg[0][31]}}, mac_reg[0][31:16]};
				3'd2: data_write_mult = {{16{result_reg[0][31]}}, result_reg[0][31:16]};
				3'd3: data_write_mult = {{16{result_reg[1][31]}}, result_reg[1][31:16]};
			endcase	
		 end
	end
end


endmodule