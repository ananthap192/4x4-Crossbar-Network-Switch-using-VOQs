module crossbar_4by4 (
    input  wire [7:0] data_in_0,
    input  wire [7:0] data_in_1,
    input  wire [7:0] data_in_2,
    input  wire [7:0] data_in_3,
    input  wire [7:0]  xbar_control,
    input  wire [3:0]  out_valid,
    output reg  [7:0] data_out_0,
    output reg  [7:0] data_out_1,
    output reg  [7:0] data_out_2,
    output reg  [7:0] data_out_3
);

    always @(*) begin
        if (out_valid[0]) begin
            case (xbar_control[1:0])
                2'b00: data_out_0 = data_in_0;
                2'b01: data_out_0 = data_in_1;
                2'b10: data_out_0 = data_in_2;
                2'b11: data_out_0 = data_in_3;
            endcase
        end else begin
            data_out_0 = 8'd0;
        end
    end

    always @(*) begin
        if (out_valid[1]) begin 
            case (xbar_control[3:2])
                2'b00: data_out_1 = data_in_0;
                2'b01: data_out_1 = data_in_1;
                2'b10: data_out_1 = data_in_2;
                2'b11: data_out_1 = data_in_3;
            endcase
        end else begin
            data_out_1 = 8'd0; 
        end
    end
    
    always @(*) begin
        if (out_valid[2]) begin
            case (xbar_control[5:4])
                2'b00: data_out_2 = data_in_0;
                2'b01: data_out_2 = data_in_1;
                2'b10: data_out_2 = data_in_2;
                2'b11: data_out_2 = data_in_3;
            endcase
        end else begin
            data_out_2 = 8'd0; 
        end
    end

    always @(*) begin
        if (out_valid[3]) begin
            case (xbar_control[7:6])
                2'b00: data_out_3 = data_in_0;
                2'b01: data_out_3 = data_in_1;
                2'b10: data_out_3 = data_in_2;
                2'b11: data_out_3 = data_in_3;
            endcase
        end else begin
            data_out_3 = 8'd0; 
        end
    end

endmodule
