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
