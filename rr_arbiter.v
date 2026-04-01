module rr_arbiter (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] req_signals,
    output reg  [15:0] grant_signals,
    output reg  [7:0]  xbar_control,
    output reg [3:0] out_valid
);

    reg [1:0] ptr_out [3:0];
    reg [1:0] ptr_in  [3:0];

    reg [3:0] stage1_grant [3:0];
    reg [1:0] stage1_winner [3:0];
    reg       stage1_has_grant [3:0];

    reg [1:0] stage2_chosen [3:0];
    reg       stage2_has_accept [3:0];

    integer j, k;
    reg [1:0] search_idx;

    always @(*) begin
        grant_signals = 16'd0;
        xbar_control  = 8'd0;
        out_valid     = 4'b0000; 
        
        for (j = 0; j < 4; j = j + 1) begin
            stage1_has_grant[j]  = 0;
            stage1_winner[j]     = 0;
            stage1_grant[j]      = 4'b0000;
            
            stage2_has_accept[j] = 0;
            stage2_chosen[j]     = 0;
        end

        for (j = 0; j < 4; j = j + 1) begin
            for (k = 0; k < 4; k = k + 1) begin
                search_idx = (ptr_out[j] + k) % 4;

                if (req_signals[search_idx * 4 + j] && !stage1_has_grant[j]) begin
                    stage1_has_grant[j] = 1;                                          
                    stage1_winner[j]    = search_idx;
                    stage1_grant[j][search_idx] = 1; 
                    out_valid[j] = 1;
                end
            end
        end

        for (j = 0; j < 4; j = j + 1) begin
            for (k = 0; k < 4; k = k + 1) begin
                search_idx = (ptr_in[j] + k) % 4;

                if (stage1_grant[search_idx][j] && !stage2_has_accept[j]) begin
                    stage2_has_accept[j] = 1;
                    stage2_chosen[j]     = search_idx;

                    grant_signals[j * 4 + search_idx] = 1;

                    xbar_control[ (search_idx * 2) +: 2 ] = j;
                end
            end
        end
    end

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1) begin
                ptr_out[i] <= 2'b00;                              
                ptr_in[i]  <= 2'b00;
            end
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                if (stage1_has_grant[i]) begin
                    ptr_out[i] <= (stage1_winner[i] + 1) % 4;
                end
            end

            for (i = 0; i < 4; i = i + 1) begin
                if (stage2_has_accept[i]) begin
                    ptr_in[i] <= (stage2_chosen[i] + 1) % 4; 
                end
            end
        end
    end

endmodule



