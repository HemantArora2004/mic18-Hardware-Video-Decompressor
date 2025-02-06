module milestone3 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// reset                      			////////////
		input logic resetn,                       // async reset
		
		/////// enable                      	   ///////////
		input logic ena,                          // enable module
		output logic done,
		input wr_en,

		
		/////// SRAM Interface                    ////////////
		output logic [17:0] SRAM_address,
		output logic [15:0] SRAM_write_data,
		output logic SRAM_we_n,
		input  logic [15:0] SRAM_read_data, 
		
		
		output logic write_en_decode,
		output logic [5:0] write_address_decode,
		output logic [31:0] write_data_decode
		
);

assign SRAM_we_n = 1'b1;
typedef enum logic [2:0] {
	S_IDLE,
	S_LI1,
	S_DECODE,
	S_WRITE,
	S_READ,
	S_DONE
} state_type;


state_type state;

logic [5:0] index_count, index_count_delay;
logic [5:0] count;
logic [15:0] data;
logic [15:0] memory_data;

logic write_en_dealy1, write_en_dealy2;
logic [7:0] write_prt_delay1, write_prt_delay2;


logic [31:0] shift_reg;

logic [4:0] shift_count;

logic [3:0] op_code;

logic [7:0] read_ptr, write_prt;

logic [15:0] read_data, write_data;
logic write_en;
logic full;




dual_port_RAM0 RAM_inst0 (
	.address_a ( write_prt_delay2 ),
	.address_b ( read_ptr ),
	
	.clock ( CLOCK_50_I ),
	
	.data_a ( write_data ),
	.data_b ( 16'd0 ),
	
	.wren_a ( write_en_dealy2 ),
	.wren_b ( 1'b0 ),
	.q_a (),
	.q_b ( read_data )
);

assign full = write_prt + 7'd1 == read_ptr ? 1'b1 : 1'b0;

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		index_count <= 6'd0;
		count <= 6'd0;
		SRAM_address <= 18'd76804;
		op_code <= 3'd0;
		shift_count <= 5'd0;
		data <= 16'd0;
		shift_reg <= 32'd0;
		read_ptr <= 8'd4;
		write_prt <= 8'd0;
		write_data <= 16'd0;
		memory_data <= 16'd0;
		index_count_delay <= 6'd0;
		write_en <= 1'b0;
		state <= S_IDLE;
		write_en_decode <= 1'b0;
		done <= 1'b0;
	end else begin
		index_count_delay <= index_count;
		write_en_decode <= 1'b0;
		write_en <= 1'b0;
		
		write_en_dealy1 <= write_en;
		write_en_dealy2 <= write_en_dealy1;
		
		write_prt_delay1 <= write_prt;
		write_prt_delay2 <= write_prt_delay1;
		
		 // Check if buffer is full
		if (wr_en && !full) begin
				SRAM_address <= SRAM_address + 18'd1;
            write_data <= SRAM_read_data;         // Write data into the buffer
            write_prt <= write_prt + 8'd1;         // Move write pointer
				write_en <= 1'b1;
      end
		
		
		if(write_en_dealy1) begin 
			write_data <= SRAM_read_data; 
		end
		
		case(state) 
			S_IDLE: begin 
				if(ena == 1'b1) begin 
						state <= S_LI1;
				end
			end
			
			S_LI1: begin 
				write_en <= 1'b0;
				
				if(write_prt_delay2 == 8'd0)begin 
						shift_reg <= {SRAM_read_data, shift_reg[15:0]};
					end else if(write_prt_delay2 == 8'd1) begin 
						shift_reg <= {shift_reg[31:16],SRAM_read_data};
					end else if(write_prt_delay2 == 8'd2) begin 
						memory_data <= SRAM_read_data;
					end
				
				if(write_prt < 8'd255) begin 
					SRAM_address <= SRAM_address + 18'd1;
					write_prt <= write_prt + 8'd1;
					write_en <= 1'b1;
				end else begin 
					state <= S_DECODE;	
					count <= 5'd0;
				end
			end
			
			S_DECODE: begin 
				state <= S_WRITE;
				count <= 5'd0;
				done <= 1'b0;
				casex(shift_reg[31:28])
					4'b00??: op_code <= 3'd1;
					4'b01??: op_code <= 3'd2;
					4'b100?:op_code <= 3'd3;
					4'b1011:op_code <= 3'd4;
					4'b1010:op_code <= 3'd5;
					4'b11??:op_code <= 3'd6;
					default: op_code <= 3'd0;
				endcase
			end
			
			
			S_WRITE: begin 
			
				if(index_count == 6'd63) begin 
					state <= S_DONE;
				end else begin 
					state <= S_DECODE;
				end
				
				write_en_decode <= 1'b1;
				count <= count + 6'd1;
				if(index_count != 6'd63)begin 
					index_count <= index_count + 6'd1;
				end
				casex(op_code)
				
					3'd1: begin
						if(count == 6'd0) begin 
							data <= {{13{shift_reg[29]}}, shift_reg[29:27]};
							state <= S_WRITE;
						end else begin 
							data <= {{13{shift_reg[26]}}, shift_reg[26:24]};
							shift_reg <= {shift_reg[23:0],memory_data[15:8]};
							memory_data <= memory_data << 8;
							shift_count <= shift_count + 5'd8;
							if(shift_count + 5'd8 > 5'd16) begin 
									state <= S_READ;
									shift_count <= shift_count - 5'd16 + 5'd8;
							end
						end
					end
					
					3'd2: begin
						data <= {{13{shift_reg[29]}}, shift_reg[29:27]};
						shift_reg <=  {shift_reg[26:0],memory_data[15:11]};
						memory_data <= memory_data << 5;
						shift_count <= shift_count + 5'd5;
						if(shift_count + 5'd5 > 5'd16) begin 
							state <= S_READ;
							shift_count <= shift_count - 5'd16 + 5'd5;
						end
					end
					
					3'd3: begin
						data <= {{10{shift_reg[28]}}, shift_reg[28:23]};
						shift_reg <= {shift_reg[22:0],memory_data[15:7]};
						memory_data <= memory_data << 9;
						shift_count <= shift_count + 5'd9;
						if(shift_count + 5'd9> 5'd16) begin 
							state <= S_READ;
							shift_count <= shift_count - 5'd16 + 5'd9;
						end
					end
					
					3'd4: begin
						data <= {{7{shift_reg[27]}}, shift_reg[27:19]};
						shift_reg <= {shift_reg[18:0],memory_data[15:3]};
						memory_data <= memory_data << 13;
						shift_count <= shift_count + 5'd13;
						if(shift_count + 5'd13 > 5'd16) begin 
							state <= S_READ;
							shift_count <= shift_count - 5'd16 + 5'd13;
						end
					end
					
					3'd5: begin
						if(index_count < 6'd63) begin
							data <= 16'd0;
							state <= S_WRITE;
						end else begin 
							data <= 16'd0;
							shift_reg <=  {shift_reg[27:0],memory_data[15:12]};
							memory_data <= memory_data << 4;
							shift_count <= shift_count + 5'd4;
							state <= S_DONE;
							if(shift_count + 5'd4 > 5'd16) begin 
								state <= S_READ;
								shift_count <= shift_count - 5'd16 + 5'd4;
							end
						end
					end
					
					3'd6: begin
					
						if(shift_reg[29:27] == 3'd0) begin 
							if(count < 6'd7) begin
								data <= 16'd0;
								state <= S_WRITE;
							end else begin 
								data <= 16'd0;
								shift_reg <=  {shift_reg[26:0],memory_data[15:11]};
								memory_data <= memory_data << 5;
								shift_count <= shift_count + 5'd5;
								if(shift_count + 5'd5 > 5'd16) begin 
									state <= S_READ;
									shift_count <= shift_count - 5'd16 + 5'd5;
								end
							end
						end else begin 
							if(count < {3'b000, shift_reg[29:27]} - 6'd1) begin
								data <= 16'd0;
								state <= S_WRITE;
							end else begin
								data <= 16'd0;
								shift_reg <=  {shift_reg[26:0],memory_data[15:11]};
								memory_data <= memory_data << 5;
								shift_count <= shift_count + 5'd5;
								if(shift_count + 5'd5 > 5'd16) begin 
									state <= S_READ;
									shift_count <= shift_count - 5'd16 + 5'd5;
								end
							end
	
						end
						
						
					end
				endcase
			end
					
			S_READ: begin 
				shift_reg <= (shift_reg & (32'hFFFFFFFF << shift_count)) | (({16'b0, read_data} >> (5'd16-shift_count)));
				memory_data <= (read_data << (shift_count));
				read_ptr <= read_ptr + 8'd1;
				
				if(index_count_delay == 6'd63) begin 
					state <= S_DONE;
				end else begin
					state <= S_DECODE;
				end
			end
			
			S_DONE: begin 
				index_count <= 6'd0;
				done <= 1'b1;
				if(ena == 1'b1) begin 
						state <= S_DECODE;
				end
			end
		endcase
	end
end







always_comb begin 
 case (index_count_delay)
        6'd0:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd0; end  
        6'd1:  begin write_data_decode = {{16{data[15]}} , data << 2}; write_address_decode = 6'd1; end  
		  6'd2:  begin write_data_decode = {{16{data[15]}} , data << 2}; write_address_decode = 6'd8; end 
        6'd3:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd16; end  
        6'd4:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd9; end  
        6'd5:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd2; end  
        6'd6:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd3; end  
        6'd7:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd10; end  
        6'd8:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd17; end  
        6'd9:  begin write_data_decode = {{16{data[15]}} , data << 3}; write_address_decode = 6'd24; end  
        6'd10: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd32; end  
        6'd11: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd25; end  
        6'd12: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd18; end  
        6'd13: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd11; end  
        6'd14: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd4; end  
        6'd15: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd5; end  
        6'd16: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd12; end  
        6'd17: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd19; end  
        6'd18: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd26; end  
        6'd19: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd33; end  
        6'd20: begin write_data_decode = {{16{data[15]}} , data << 4}; write_address_decode = 6'd40; end  
        6'd21: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd48; end  
        6'd22: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd41; end  
        6'd23: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd34; end  
        6'd24: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd27; end  
        6'd25: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd20; end  
        6'd26: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd13; end  
        6'd27: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd6; end  
        6'd28: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd7; end  
        6'd29: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd14; end  
        6'd30: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd21; end  
        6'd31: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd28; end  
        6'd32: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd35; end  
        6'd33: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd42; end  
        6'd34: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd49; end  
        6'd35: begin write_data_decode = {{16{data[15]}} , data << 5}; write_address_decode = 6'd56; end  
        6'd36: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd57; end  
        6'd37: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd50; end  
        6'd38: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd43; end  
        6'd39: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd36; end  
        6'd40: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd29; end  
        6'd41: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd22; end  
        6'd42: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd15; end  
        6'd43: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd23; end  
        6'd44: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd30; end  
        6'd45: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd37; end  
        6'd46: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd44; end  
        6'd47: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd51; end  
        6'd48: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd58; end  
        6'd49: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd59; end  
        6'd50: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd52; end  
        6'd51: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd45; end  
        6'd52: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd38; end  
        6'd53: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd31; end  
        6'd54: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd39; end  
        6'd55: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd46; end  
        6'd56: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd53; end  
        6'd57: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd60; end  
        6'd58: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd61; end  
        6'd59: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd54; end  
        6'd60: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd47; end  
        6'd61: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd55; end  
        6'd62: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd62; end  
        6'd63: begin write_data_decode = {{16{data[15]}} , data << 6}; write_address_decode = 6'd63; end 
    endcase
end


endmodule