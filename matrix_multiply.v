module matrix_multiply
    #(  parameter width = 8,            
        parameter A_depth_bits = 3,     
        parameter B_depth_bits = 2, 
        parameter RES_depth_bits = 1
    ) 
    (
        input wire clk,                                          
        input wire rst_n,
        input wire Start,                                        
        output reg Done,                                    
        
        output reg A_read_en,                               
        output reg [A_depth_bits-1:0] A_read_address,       
        input wire [width-1:0] A_read_data_out,                  
        
        output reg B_read_en,                               
        output reg [B_depth_bits-1:0] B_read_address,       
        input wire [width-1:0] B_read_data_out,                  
        
        output reg RES_write_en,                            
        output reg [RES_depth_bits-1:0] RES_write_address,  
        output wire [width-1:0] RES_write_data_in           
    );


    // Parameters for matrix dimensions
    localparam A_CNT = 1<<A_depth_bits;
    localparam B_CNT = 1<<B_depth_bits;

    reg [A_depth_bits:0] A_cnt;
    reg [B_depth_bits:0] B_cnt;
    reg [RES_depth_bits-1:0] RES_cnt;

    reg [31:0] int_result;
    wire [31:0] pre_result; 
    
    reg RES_out_MAC;
    reg RES_rst_MAC;
    reg RES_out_STORE;
    reg RES_rst_STORE;
    reg RES_write_en_MAC;
    reg [RES_depth_bits-1:0] RES_write_address_MAC;

	reg [1:0] start_counter;

	reg A_read_en_delay;
    // reg Done_delay;



    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_read_en <= 1'b0;
            B_read_en <= 1'b0;
            A_read_address <= 'b0;
            B_read_address <= 'b0;
            A_cnt <= 'b0;
            B_cnt <= 'b0;
            RES_cnt <= 'b0;
            int_result <= 'b0;
            Done <= 1'b0;

            
            RES_out_MAC <= 1'b0;
            RES_rst_MAC <= 1'b1;
            RES_write_en_MAC <= 1'b0;
            RES_write_address_MAC <= 'b0;

        end else if (Start) begin  // start is level signal
			if (A_read_en_delay) begin
                int_result <= pre_result + A_read_data_out * B_read_data_out;
			end
			
            if (A_cnt < A_CNT && B_cnt < B_CNT) begin
                A_read_en <= 1'b1;
                B_read_en <= 1'b1;
                
                RES_write_en_MAC <= 1'b0; 

                A_cnt <= A_cnt + 1;
                B_cnt <= B_cnt + 1;

                //int_result <= pre_result + A_read_data_out * B_read_data_out;
                Done <= 1'b0;
                A_read_address <= A_cnt;
                B_read_address <= B_cnt;
                
                RES_out_MAC <= 1'b0; 
                RES_rst_MAC <= 1'b0; 
            end
            else if (A_cnt < A_CNT && B_cnt == B_CNT) begin 
                RES_write_en_MAC <= 1'b1;
                RES_cnt <= RES_cnt + 1;
                RES_write_address_MAC <= RES_cnt;
                
                A_cnt <= A_cnt + 1;
                B_cnt <= 'b1; // for next cycle
                A_read_en <= 1'b1;
                B_read_en <= 1'b1;
                A_read_address <= A_cnt;
                B_read_address <= 'b0;

                RES_out_MAC <= 1'b1;
                RES_rst_MAC <= 1'b1;

                //int_result <= pre_result + A_read_data_out * B_read_data_out;
            end
            else begin // Done State
                A_read_en <= 1'b1;
                B_read_en <= 1'b1;
                A_read_address <= 'b0;
                B_read_address <= 'b0;
                
                RES_write_en_MAC <= 1'b1;
                RES_write_address_MAC <= RES_cnt;

                RES_out_MAC <= 1'b1;
                RES_rst_MAC <= 1'b1;

                //int_result <= pre_result + A_read_data_out * B_read_data_out;

                A_cnt <= 'b1;
                B_cnt <= 'b1;
                RES_cnt <= 'b0;
                Done <= 1'b1;
            end
        end else begin //after start is deasserted
            //int_result <= int_result;
            RES_write_en_MAC <= 1'b0;
            RES_out_MAC <= 1'b0;
            RES_rst_MAC <= 1'b1; 
            A_read_en <= 1'b0;
            B_read_en <= 1'b0;
            A_cnt <= 'b0;
            B_cnt <= 'b0;
            RES_cnt <= 'b0;
            Done <= 1'b0;
            RES_write_en_MAC <= 1'b0;
            RES_write_address_MAC <= 'b0;
        end
    end 

	//pipeline delay
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            RES_write_en <= 1'b0;
            RES_write_address <= 'b0;
            RES_out_STORE <= 1'b0;
            RES_rst_STORE <= 1'b1;
			A_read_en_delay <= 1'b0;
            // Done <= 1'b0;

        end else begin
            RES_out_STORE <= RES_out_MAC;
            RES_rst_STORE <= RES_rst_MAC;
            
            RES_write_en <= RES_write_en_MAC;
            RES_write_address <= RES_write_address_MAC;
			A_read_en_delay <= A_read_en;
            // Done <= Done_delay;
        end
    end


    assign RES_write_data_in = RES_out_STORE ? (int_result >> 8) : 'b0;
    
    assign pre_result = RES_rst_STORE ? 32'b0 : int_result;

endmodule
