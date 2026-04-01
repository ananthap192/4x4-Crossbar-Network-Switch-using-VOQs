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


