/* 
----------------------------------------------------------------------------------
--	(c) Rajesh C Panicker, NUS
--  Description : Matrix Multiplication AXI Stream Coprocessor. Based on the orginal AXIS Coprocessor template (c) Xilinx Inc
-- 	Based on the orginal AXIS coprocessor template (c) Xilinx Inc
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post a modified version of this on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate any intellectual property of any entity.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course EE4218 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/
/*
-------------------------------------------------------------------------------
--
-- Definition of Ports
-- ACLK              : Synchronous clock
-- ARESETN           : System reset, active low
-- S_AXIS_TREADY  : Ready to accept data in
-- S_AXIS_TDATA   :  Data in 
-- S_AXIS_TLAST   : Optional data in qualifier
-- S_AXIS_TVALID  : Data in is valid
-- M_AXIS_TVALID  :  Data out is valid
-- M_AXIS_TDATA   : Data Out
-- M_AXIS_TLAST   : Optional data out qualifier
-- M_AXIS_TREADY  : Connected slave device is ready to accept data out
--
-------------------------------------------------------------------------------
*/

module myip_v1_0 
	(
		// DO NOT EDIT BELOW THIS LINE ////////////////////
		ACLK,
		ARESETN,
		S_AXIS_TREADY,
		S_AXIS_TDATA,
		S_AXIS_TLAST,
		S_AXIS_TVALID,
		M_AXIS_TVALID,
		M_AXIS_TDATA,
		M_AXIS_TLAST,
		M_AXIS_TREADY
		// DO NOT EDIT ABOVE THIS LINE ////////////////////
	);

	input					ACLK;    // Synchronous clock
	input					ARESETN; // System reset, active low
	// slave in interface
	output	reg				S_AXIS_TREADY;  // Ready to accept data in
	input	[31 : 0]		S_AXIS_TDATA;   // Data in
	input					S_AXIS_TLAST;   // Optional data in qualifier
	input					S_AXIS_TVALID;  // Data in is valid
	// master out interface
	output	reg				M_AXIS_TVALID;  // Data out is valid
	output	wire [31 : 0]	M_AXIS_TDATA;   // Data Out
	output	reg				M_AXIS_TLAST;   // Optional data out qualifier
	input					M_AXIS_TREADY;  // Connected slave device is ready to accept data out


// RAM parameters for assignment 1
	localparam A_depth_bits = 3;  	// 8 elements (A is a 2x4 matrix)
	localparam B_depth_bits = 2; 	// 4 elements (B is a 4x1 matrix)
	localparam RES_depth_bits = 1;	// 2 elements (RES is a 2x1 matrix)
	localparam width = 8;			// all 8-bit data
	
// wires (or regs) to connect to RAMs and matrix_multiply_0 for assignment 1
// those which are assigned in an always block of myip_v1_0 shoud be changes to reg.
	reg	A_write_en;								// myip_v1_0 -> A_RAM. To be assigned within myip_v1_0. Possibly reg.
	reg	[A_depth_bits-1:0] A_write_address;		// myip_v1_0 -> A_RAM. To be assigned within myip_v1_0. Possibly reg. 
	reg	[width-1:0] A_write_data_in;			// myip_v1_0 -> A_RAM. To be assigned within myip_v1_0. Possibly reg.
	wire	A_read_en;								// matrix_multiply_0 -> A_RAM.
	wire	[A_depth_bits-1:0] A_read_address;		// matrix_multiply_0 -> A_RAM.
	wire	[width-1:0] A_read_data_out;			// A_RAM -> matrix_multiply_0.
	reg	B_write_en;								// myip_v1_0 -> B_RAM. To be assigned within myip_v1_0. Possibly reg.
	reg	[B_depth_bits-1:0] B_write_address;		// myip_v1_0 -> B_RAM. To be assigned within myip_v1_0. Possibly reg.
	reg	[width-1:0] B_write_data_in;			// myip_v1_0 -> B_RAM. To be assigned within myip_v1_0. Possibly reg.
	wire	B_read_en;								// matrix_multiply_0 -> B_RAM.
	wire	[B_depth_bits-1:0] B_read_address;		// matrix_multiply_0 -> B_RAM.
	wire	[width-1:0] B_read_data_out;			// B_RAM -> matrix_multiply_0.
	wire	RES_write_en;							// matrix_multiply_0 -> RES_RAM.
	wire	[RES_depth_bits-1:0] RES_write_address;	// matrix_multiply_0 -> RES_RAM.
	wire	[width-1:0] RES_write_data_in;			// matrix_multiply_0 -> RES_RAM.
	reg	RES_read_en;  							// myip_v1_0 -> RES_RAM. To be assigned within myip_v1_0. Possibly reg.
	reg	[RES_depth_bits-1:0] RES_read_address;	// myip_v1_0 -> RES_RAM. To be assigned within myip_v1_0. Possibly reg.
	wire	[width-1:0] RES_read_data_out;			// RES_RAM -> myip_v1_0
	
	// wires (or regs) to connect to matrix_multiply for assignment 1
	reg	Start; 								// myip_v1_0 -> matrix_multiply_0. To be assigned within myip_v1_0. Possibly reg.
	wire	Done;								// matrix_multiply_0 -> myip_v1_0. 
			
				
	// Total number of input data.
	localparam NUMBER_OF_INPUT_WORDS  = 12; // 2**A_depth_bits + 2**B_depth_bits = 12 for assignment 1
	localparam NUMBER_OF_INPUT_WORDS_A  = 8; // 2**A_depth_bits = 8 for assignment 1
	localparam NUMBER_OF_INPUT_WORDS_B  = 4; // 2**B_depth_bits = 4 for assignment 1

	// Total number of output data
	localparam NUMBER_OF_OUTPUT_WORDS = 2; // 2**RES_depth_bits = 2 for assignment 1

	localparam DATA_BITS = 8; // data width is 8 bits for assignment 1

	// Define the states of state machine (one hot encoding)
	localparam Idle  = 4'b0000;
	localparam Receive = 4'b0001;
	localparam Compute = 4'b0010;
	localparam Send_wait  = 4'b0100;
	localparam Send  = 4'b1000;

	reg [3:0] state;



	// Counters to store the number inputs read & outputs written.
	// Could be done using the same counter if reads and writes are not overlapped (i.e., no dataflow optimization)
	// Left as separate for ease of debugging
	reg [$clog2(NUMBER_OF_INPUT_WORDS) - 1:0] receive_counter;
	reg [$clog2(NUMBER_OF_OUTPUT_WORDS) - 1:0] send_counter;


	// State transitions
	always @(posedge ACLK or negedge ARESETN) begin
		if (!ARESETN)
			state <= Idle;
		else

		begin
			case (state)
				Idle:
					if (S_AXIS_TVALID)
						state <= Receive;
				Receive:
					if (receive_counter == NUMBER_OF_INPUT_WORDS)
						state <= Compute;
				Compute:
					if (Done)
						state <= Send_wait;
				Send_wait:
					// if (M_AXIS_TREADY)
						state <= Send;
				Send:
					if (send_counter == NUMBER_OF_OUTPUT_WORDS-1 && M_AXIS_TREADY && RES_write_en == 1'b0)
						state <= Idle;
					
				
			endcase
		end
	end

	always @(posedge ACLK) begin
		case (state)
			Idle: begin
				S_AXIS_TREADY <= 1'b0;
				M_AXIS_TVALID <= 1'b0;
				M_AXIS_TLAST <= 1'b0;
				A_write_en <= 1'b0;
				A_write_address <= 'b0;
				A_write_data_in <= 'b0;
				B_write_en <= 1'b0;
				B_write_address <= 'b0;
				B_write_data_in <= 'b0;
				RES_read_en <= 1'b0;
				RES_read_address <= 'b0;
				Start <= 1'b0;
				receive_counter <= 'b0;
				send_counter <= 'b0;
			end
			Receive: begin
				S_AXIS_TREADY <= 1'b1;
				if (S_AXIS_TVALID && S_AXIS_TREADY) begin
					if (receive_counter < NUMBER_OF_INPUT_WORDS_A) begin
						// Writing to A RAM
						B_write_en <= 1'b0;
						A_write_en <= 1'b1;
						A_write_address <= receive_counter[A_depth_bits-1:0]; // bits alignment
						A_write_data_in <= S_AXIS_TDATA[DATA_BITS-1:0]; 
						
					end else begin
						// Writing to B RAM
						A_write_en <= 1'b0;
						B_write_en <= 1'b1;
						B_write_address <= (receive_counter - NUMBER_OF_INPUT_WORDS_A);
						B_write_data_in <= S_AXIS_TDATA[DATA_BITS-1:0]; 
						
					end
					receive_counter <= receive_counter + 1;
				end
				else begin
					A_write_en <= 1'b0;
					B_write_en <= 1'b0;
					receive_counter <= receive_counter;
				end
				
			end
			Compute: begin
				B_write_en <= 1'b0;
				A_write_en <= 1'b0;
				S_AXIS_TREADY <= 1'b0;
				Start <= 1'b1;
			end
			Send_wait: begin
				Start <= 1'b0;
				// M_AXIS_TVALID <= 1'b1;
				RES_read_en <= 1'b1;
				RES_read_address <= send_counter[RES_depth_bits-1:0];
				// M_AXIS_TDATA[DATA_BITS-1:0] <= RES_read_data_out; 
			end
			Send: begin
				M_AXIS_TVALID <= 1'b1;
				RES_read_en <= 1'b1;
				//M_AXIS_TDATA[DATA_BITS-1:0] <= RES_read_data_out; 
				
				if (M_AXIS_TREADY) begin
					send_counter <= send_counter + 1;
					RES_read_address <= send_counter + 1;
					
				end
				else begin
					send_counter <= send_counter;
					RES_read_address <= send_counter;
				end

				if (send_counter == NUMBER_OF_OUTPUT_WORDS - 1)
					M_AXIS_TLAST <= 1'b1;
			end
		endcase
		
	end
	   
	assign M_AXIS_TDATA = {{(32-DATA_BITS){1'b0}}, RES_read_data_out};
	// Connection to sub-modules / components for assignment 1
	
	memory_RAM 
	#(
		.width(width), 
		.depth_bits(A_depth_bits)
	) A_RAM 
	(
		.clk(ACLK),
		.write_en(A_write_en),
		.write_address(A_write_address),
		.write_data_in(A_write_data_in),
		.read_en(A_read_en),    
		.read_address(A_read_address),
		.read_data_out(A_read_data_out)
	);
										
										
	memory_RAM 
	#(
		.width(width), 
		.depth_bits(B_depth_bits)
	) B_RAM 
	(
		.clk(ACLK),
		.write_en(B_write_en),
		.write_address(B_write_address),
		.write_data_in(B_write_data_in),
		.read_en(B_read_en),    
		.read_address(B_read_address),
		.read_data_out(B_read_data_out)
	);
										
										
	memory_RAM 
	#(
		.width(width), 
		.depth_bits(RES_depth_bits)
	) RES_RAM 
	(
		.clk(ACLK),
		.write_en(RES_write_en),
		.write_address(RES_write_address),
		.write_data_in(RES_write_data_in),
		.read_en(RES_read_en),    
		.read_address(RES_read_address),
		.read_data_out(RES_read_data_out)
	);
										
	matrix_multiply 
	#(
		.width(width), 
		.A_depth_bits(A_depth_bits), 
		.B_depth_bits(B_depth_bits), 
		.RES_depth_bits(RES_depth_bits) 
	) matrix_multiply_0
	(									
		.clk(ACLK),
		.Start(Start), // level signal, clear when the calculation is done
		.Done(Done),
		.rst_n(ARESETN),
		
		.A_read_en(A_read_en),
		.A_read_address(A_read_address),
		.A_read_data_out(A_read_data_out),
		
		.B_read_en(B_read_en),
		.B_read_address(B_read_address),
		.B_read_data_out(B_read_data_out),
		
		.RES_write_en(RES_write_en),
		.RES_write_address(RES_write_address),
		.RES_write_data_in(RES_write_data_in)
	);

endmodule
