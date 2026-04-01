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
