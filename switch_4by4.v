module switch_4by4 (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0] data_in_0,
    input  wire        valid_in_0,
    input  wire [1:0]  dest_in_0,

    input  wire [7:0] data_in_1,
    input  wire        valid_in_1,
    input  wire [1:0]  dest_in_1,

    input  wire [7:0] data_in_2,
    input  wire        valid_in_2,
    input  wire [1:0]  dest_in_2,

    input  wire [7:0] data_in_3,
    input  wire        valid_in_3,
    input  wire [1:0]  dest_in_3,

    output wire [7:0] data_out_0,
    output wire [7:0] data_out_1,
    output wire [7:0] data_out_2,
    output wire [7:0] data_out_3
);

    wire [15:0] req_bus; 
    wire [15:0] grant_bus;
    wire [7:0] xbar_in_0;
    wire [7:0] xbar_in_1;
    wire [7:0] xbar_in_2;
    wire [7:0] xbar_in_3;
    wire [7:0]  xbar_ctrl;
    wire [3:0] arb_out_valid;

    input_port PORT_0 (
        .clk(clk), .rst(rst),
        .data_in(data_in_0), .valid_in(valid_in_0), .dest_in(dest_in_0),
        .req_vec(req_bus[3:0]),      
        .grant_vec(grant_bus[3:0]),
        .xbar_data_out(xbar_in_0)
    );

    input_port PORT_1 (
        .clk(clk), .rst(rst),
        .data_in(data_in_1), .valid_in(valid_in_1), .dest_in(dest_in_1),
        .req_vec(req_bus[7:4]),      
        .grant_vec(grant_bus[7:4]),
        .xbar_data_out(xbar_in_1)
    );

    input_port PORT_2 (
        .clk(clk), .rst(rst),
        .data_in(data_in_2), .valid_in(valid_in_2), .dest_in(dest_in_2),
        .req_vec(req_bus[11:8]),      
        .grant_vec(grant_bus[11:8]),
        .xbar_data_out(xbar_in_2)
    );

    input_port PORT_3 (
        .clk(clk), .rst(rst),
        .data_in(data_in_3), .valid_in(valid_in_3), .dest_in(dest_in_3),
        .req_vec(req_bus[15:12]),      
        .grant_vec(grant_bus[15:12]),
        .xbar_data_out(xbar_in_3)
    );

    rr_arbiter ARBITER (
        .clk(clk),
        .rst(rst),
        .req_signals(req_bus),
        .grant_signals(grant_bus),
        .xbar_control(xbar_ctrl),
        .out_valid(arb_out_valid)
    );

    crossbar_4by4 CROSSBAR (
        .data_in_0(xbar_in_0),
        .data_in_1(xbar_in_1),
        .data_in_2(xbar_in_2),
        .data_in_3(xbar_in_3),
        .xbar_control(xbar_ctrl),
        .out_valid(arb_out_valid),
        .data_out_0(data_out_0),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2),
        .data_out_3(data_out_3)
    );

endmodule

module input_port (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0] data_in,
    input  wire        valid_in,
    input  wire [1:0]  dest_in,
    input  wire [3:0]  grant_vec,
    output wire [3:0]  req_vec,
    output reg  [7:0] xbar_data_out
);

    wire [7:0] fifo_out_0, fifo_out_1, fifo_out_2, fifo_out_3;
    wire        empty_0,    empty_1,    empty_2,    empty_3;
    wire        full_0,     full_1,     full_2,     full_3;
    
    reg         write_en_0, write_en_1, write_en_2, write_en_3;

    always @(*) begin
        write_en_0 = 0;
        write_en_1 = 0;
        write_en_2 = 0;
        write_en_3 = 0;

        if (valid_in) begin
            case (dest_in)
                2'b00: write_en_0 = 1;
                2'b01: write_en_1 = 1;
                2'b10: write_en_2 = 1;
                2'b11: write_en_3 = 1;
            endcase
        end
    end

    simple_fifo voq_0 (
        .clk(clk), .rst(rst),
        .write_en(write_en_0), .data_in(data_in), .full(full_0),
        .read_en(grant_vec[0]), .data_out(fifo_out_0), .empty(empty_0)
    );

    simple_fifo voq_1 (
        .clk(clk), .rst(rst),
        .write_en(write_en_1), .data_in(data_in), .full(full_1),
        .read_en(grant_vec[1]), .data_out(fifo_out_1), .empty(empty_1)
    );

    simple_fifo voq_2 (
        .clk(clk), .rst(rst),
        .write_en(write_en_2), .data_in(data_in), .full(full_2),
        .read_en(grant_vec[2]), .data_out(fifo_out_2), .empty(empty_2)
    );

    simple_fifo voq_3 (
        .clk(clk), .rst(rst),
        .write_en(write_en_3), .data_in(data_in), .full(full_3),
        .read_en(grant_vec[3]), .data_out(fifo_out_3), .empty(empty_3)
    );

    assign req_vec[0] = !empty_0;
    assign req_vec[1] = !empty_1;
    assign req_vec[2] = !empty_2;
    assign req_vec[3] = !empty_3;

    always @(*) begin
        xbar_data_out = 32'd0; 

        if (grant_vec[0])      xbar_data_out = fifo_out_0;
        else if (grant_vec[1]) xbar_data_out = fifo_out_1;
        else if (grant_vec[2]) xbar_data_out = fifo_out_2;
        else if (grant_vec[3]) xbar_data_out = fifo_out_3;
    end

endmodule

module simple_fifo (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_en,
    input  wire [7:0] data_in,
    output wire        full,
    input  wire        read_en,
    output wire [7:0] data_out,
    output wire        empty
);

    reg [7:0] mem_array [7:0];
    reg [2:0] write_ptr;
    reg [2:0] read_ptr;
    reg [3:0] count;

    assign empty = (count == 0);
    assign full  = (count == 8);
    assign data_out = (!empty) ? mem_array[read_ptr] : 8'd0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr <= 0;
            read_ptr  <= 0;
            count     <= 0;
        end else begin
            if (write_en && !full) begin
                mem_array[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
            end

            if (read_en && !empty) begin
                read_ptr <= read_ptr + 1; 
            end
            
            if (write_en && !full && !(read_en && !empty))
                count <= count + 1;
            else if (read_en && !empty && !(write_en && !full))
                count <= count - 1;
        end
    end
endmodule
