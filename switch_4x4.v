//4by4switch
`timescale 1ns / 1ps


module switch_4by4 (
    input  wire        clk,
    input  wire        rst,

    // --- Input Port 0 Interface ---
    input  wire [7:0] data_in_0,
    input  wire        valid_in_0,
    input  wire [1:0]  dest_in_0,

    // --- Input Port 1 Interface ---
    input  wire [7:0] data_in_1,
    input  wire        valid_in_1,
    input  wire [1:0]  dest_in_1,

    // --- Input Port 2 Interface ---
    input  wire [7:0] data_in_2,
    input  wire        valid_in_2,
    input  wire [1:0]  dest_in_2,

    // --- Input Port 3 Interface ---
    input  wire [7:0] data_in_3,
    input  wire        valid_in_3,
    input  wire [1:0]  dest_in_3,

    // --- Outputs (To the outside world) ---
    output wire [7:0] data_out_0,
    output wire [7:0] data_out_1,
    output wire [7:0] data_out_2,
    output wire [7:0] data_out_3
);

    // ============================================================
    // INTERNAL WIRES (The Glue)
    // ============================================================

    // 1. Request Signals (Input Port -> Arbiter)
    //    Flat 16-bit vector: [In0_VOQ0, In0_VOQ1... In3_VOQ3]
    wire [15:0] req_bus; 

    // 2. Grant Signals (Arbiter -> Input Port)
    //    Flat 16-bit vector
    wire [15:0] grant_bus;

    // 3. Crossbar Data (Input Port -> Crossbar)
    //    The "Pop" output from the chosen VOQ
    wire [7:0] xbar_in_0;
    wire [7:0] xbar_in_1;
    wire [7:0] xbar_in_2;
    wire [7:0] xbar_in_3;

    // 4. Crossbar Control (Arbiter -> Crossbar)
    //    Tells the switch how to route
    wire [7:0]  xbar_ctrl;
    // Telling to connect to 0 if no real input
    wire [3:0] arb_out_valid;


    // ============================================================
    // MODULE INSTANTIATIONS
    // ============================================================

    // --- 1. THE INPUT PORTS (x4) ---
    
    // Input Port 0
    input_port PORT_0 (
        .clk(clk), .rst(rst),
        .data_in(data_in_0), .valid_in(valid_in_0), .dest_in(dest_in_0),
        // Connect lower 4 bits of buses
        .req_vec(req_bus[3:0]),      
        .grant_vec(grant_bus[3:0]),
        .xbar_data_out(xbar_in_0)
    );

    // Input Port 1
    input_port PORT_1 (
        .clk(clk), .rst(rst),
        .data_in(data_in_1), .valid_in(valid_in_1), .dest_in(dest_in_1),
        // Connect bits [7:4]
        .req_vec(req_bus[7:4]),      
        .grant_vec(grant_bus[7:4]),
        .xbar_data_out(xbar_in_1)
    );

    // Input Port 2
    input_port PORT_2 (
        .clk(clk), .rst(rst),
        .data_in(data_in_2), .valid_in(valid_in_2), .dest_in(dest_in_2),
        // Connect bits [11:8]
        .req_vec(req_bus[11:8]),      
        .grant_vec(grant_bus[11:8]),
        .xbar_data_out(xbar_in_2)
    );

    // Input Port 3
    input_port PORT_3 (
        .clk(clk), .rst(rst),
        .data_in(data_in_3), .valid_in(valid_in_3), .dest_in(dest_in_3),
        // Connect bits [15:12]
        .req_vec(req_bus[15:12]),      
        .grant_vec(grant_bus[15:12]),
        .xbar_data_out(xbar_in_3)
    );


    // --- 2. THE ARBITER (The Brain) ---
    rr_arbiter ARBITER (
        .clk(clk),
        .rst(rst),
        .req_signals(req_bus),     // Takes all 16 requests
        .grant_signals(grant_bus), // Returns all 16 grants
        .xbar_control(xbar_ctrl),   // Controls the switch
        .out_valid(arb_out_valid)  // Telling validity of output
    );


    // --- 3. THE CROSSBAR (The Switch Fabric) ---
    crossbar_4by4 CROSSBAR (
        // Data Inputs (from the Input Ports)
        .data_in_0(xbar_in_0),
        .data_in_1(xbar_in_1),
        .data_in_2(xbar_in_2),
        .data_in_3(xbar_in_3),
        
        // Control (from Arbiter)
        .xbar_control(xbar_ctrl),
        .out_valid(arb_out_valid),
        
        // Outputs (to the outside world)
        .data_out_0(data_out_0),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2),
        .data_out_3(data_out_3)
    );

endmodule

//input port

module input_port (
    input  wire        clk,
    input  wire        rst,

    // --- EXTERNAL INPUTS (From the outside world) ---
    input  wire [7:0] data_in,
    input  wire        valid_in,
    input  wire [1:0]  dest_in,  // 00=Out0, 01=Out1, etc.

    // --- ARBITER INTERFACE ---
    // Note: We only handle OUR 4 bits of an input here. 
    // The top module will map these to the big 16-bit bus.
    input  wire [3:0]  grant_vec, // [0]=Grant for VOQ0, [1]=Grant for VOQ1...          4 bits of grant signals coming for that input
    output wire [3:0]  req_vec,   // [0]=Request for Out0, [1]=Request for Out1...      4 bits of request signals from that input

    // --- CROSSBAR INTERFACE ---
    output reg  [7:0] xbar_data_out // The packet sent to the switch fabric
);

    // Internal wires to connect to the 4 FIFOs
    wire [7:0] fifo_out_0, fifo_out_1, fifo_out_2, fifo_out_3;
    wire        empty_0,    empty_1,    empty_2,    empty_3;
    wire        full_0,     full_1,     full_2,     full_3;
    
    reg         write_en_0, write_en_1, write_en_2, write_en_3;

    // ============================================================
    // 1. INPUT SORTING LOGIC (Demultiplexer)
    //    Decide which VOQ gets the incoming packet.
    // ============================================================
    always @(*) begin
        // Default: Write to nobody
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

    // ============================================================
    // 2. VOQ INSTANTIATION (The 4 Buckets)
    // ============================================================
    
    // VOQ 0 (Stores packets for Output 0)
    // Read Enable comes directly from Arbiter Grant [0]
    simple_fifo voq_0 (
        .clk(clk), .rst(rst),
        .write_en(write_en_0), .data_in(data_in), .full(full_0),
        .read_en(grant_vec[0]), .data_out(fifo_out_0), .empty(empty_0)
    );

    // VOQ 1 (Stores packets for Output 1)
    simple_fifo voq_1 (
        .clk(clk), .rst(rst),
        .write_en(write_en_1), .data_in(data_in), .full(full_1),
        .read_en(grant_vec[1]), .data_out(fifo_out_1), .empty(empty_1)
    );

    // VOQ 2 (Stores packets for Output 2)
    simple_fifo voq_2 (
        .clk(clk), .rst(rst),
        .write_en(write_en_2), .data_in(data_in), .full(full_2),
        .read_en(grant_vec[2]), .data_out(fifo_out_2), .empty(empty_2)
    );

    // VOQ 3 (Stores packets for Output 3)
    simple_fifo voq_3 (
        .clk(clk), .rst(rst),
        .write_en(write_en_3), .data_in(data_in), .full(full_3),
        .read_en(grant_vec[3]), .data_out(fifo_out_3), .empty(empty_3)
    );

    // ============================================================
    // 3. REQUEST LOGIC
    //    If a VOQ is not empty, raise the Request flag.
    // ============================================================
    assign req_vec[0] = !empty_0;
    assign req_vec[1] = !empty_1;
    assign req_vec[2] = !empty_2;
    assign req_vec[3] = !empty_3;

    // ============================================================
    // 4. OUTPUT MULTIPLEXER
    //    Send the data from the Granted VOQ to the Crossbar.
    // ============================================================
    always @(*) begin
        // Default to 0
        xbar_data_out = 32'd0; 

        // Check which VOQ received the grant
        if (grant_vec[0])      xbar_data_out = fifo_out_0;
        else if (grant_vec[1]) xbar_data_out = fifo_out_1;
        else if (grant_vec[2]) xbar_data_out = fifo_out_2;
        else if (grant_vec[3]) xbar_data_out = fifo_out_3;
    end

endmodule

//fifotest1


module simple_fifo (
    input  wire        clk,
    input  wire        rst,
    
    // Write Interface
    input  wire        write_en,
    input  wire [7:0] data_in,
    output wire        full,

    // Read Interface
    input  wire        read_en,
    output wire [7:0] data_out, // <--- STEP 1: MUST BE 'wire' (not reg)
    output wire        empty
);

    // MEMORY
    reg [7:0] mem_array [7:0]; // VOQ is an array  having eight 8 bit data
    reg [2:0] write_ptr;
    reg [2:0] read_ptr;
    reg [3:0] count;

    assign empty = (count == 0);
    assign full  = (count == 8);

    // --- STEP 2: FWFT LOGIC ---
    // Show the data immediately! No clock edge required.
    assign data_out = (!empty) ? mem_array[read_ptr] : 8'd0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr <= 0;
            read_ptr  <= 0;
            count     <= 0;
            
        end else begin
            // --- WRITE LOGIC ---
            if (write_en && !full) begin
                mem_array[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
            end

            // --- READ LOGIC ---
            if (read_en && !empty) begin
                read_ptr <= read_ptr + 1; 
            end
            
            // --- COUNT LOGIC ---
            if (write_en && !full && !(read_en && !empty))
                count <= count + 1;
            else if (read_en && !empty && !(write_en && !full))
                count <= count - 1;
        end
    end
endmodule

//rrarbiter


module rr_arbiter (
    input  wire        clk,
    input  wire        rst,

    // 16 Requests (4 inputs x 4 VOQs)
    // Mapping: [Input 0 -> Out 0, Input 0 -> Out 1 ... Input 3 -> Out 3]
    input  wire [15:0] req_signals,

    // 16 Grants (One-hot per input port usually, but here specific to VOQ)
    output reg  [15:0] grant_signals,

    // Crossbar Control: 8 bits (2 bits per output port)
    // [1:0] = Select for Output 0, [3:2] = Select for Output 1, etc.
    output reg  [7:0]  xbar_control,

    //showing if output is valid or not
    output reg [3:0] out_valid

);

    // ============================================================
    // 1. POINTERS (The Memory)
    // ============================================================
    // Output Pointers (Stage 1): Tracks who each Output served last
    reg [1:0] ptr_out [3:0]; // 8 bit pointers for 4 outputs having two input bits showing which of the 4 inputs lastly served
    
    // Input Pointers (Stage 2): Tracks which Output each Input served last
    reg [1:0] ptr_in  [3:0]; // 8 bit pointers for 4 inputs having two output bits showing which of the 4 outputs lastly granted
    

    // ============================================================
    // 2. INTERNAL SIGNALS (Interconnects)
    // ============================================================
    // Stage 1 Results
    reg [3:0] stage1_grant [3:0];     // [Output][Input] bit map
    reg [1:0] stage1_winner [3:0];    // Which input won Stage 1?
    reg       stage1_has_grant [3:0]; // Did this output grant anyone?

    // Stage 2 Results
    reg [1:0] stage2_chosen [3:0];    // Which output did the Input choose?
    reg       stage2_has_accept [3:0]; // Did this input accept anyone?

    // Loop variables
    integer j, k;
    reg [1:0] search_idx; // Current index we are checking in the Round Robin circle

    // ============================================================
    // 3. COMBINATIONAL LOGIC (The Brain)
    //    Decides who wins *in this specific cycle*
    // ============================================================
    always @(*) begin
        // --- Defaults to prevent Latch generation ---
        grant_signals = 16'd0;
        xbar_control  = 8'd0; // Default to 0, though ungranted outputs will be idle
        out_valid     = 4'b0000; 
        
        // Reset internal flags
        for (j = 0; j < 4; j = j + 1) begin
            stage1_has_grant[j]  = 0;
            stage1_winner[j]     = 0;
            stage1_grant[j]      = 4'b0000;
            
            stage2_has_accept[j] = 0;
            stage2_chosen[j]     = 0;
        end

        // --- STAGE 1: OUTPUT ARBITRATION ---
        // Iterate through all 4 Outputs (j)
        for (j = 0; j < 4; j = j + 1) begin
            // Check inputs in Round-Robin order starting from ptr_out[j]
            for (k = 0; k < 4; k = k + 1) begin
                search_idx = (ptr_out[j] + k) % 4;                                     //from which input port it should start searching

                // Index logic: req_signals is flat [16 bits]. 
                // Formula: [Input_Index * 4 + Output_Index]
                if (req_signals[search_idx * 4 + j] && !stage1_has_grant[j]) begin     // search_idx -> input j -> output and making sure not granted for previous inputs
                    // Winner found!
                    stage1_has_grant[j] = 1;                                          
                    stage1_winner[j]    = search_idx;                                 // first input coming in the search list has been given grant
                    stage1_grant[j][search_idx] = 1; 
                    out_valid[j] = 1;                                                 // saying that output is valid
                end
            end
        end

        // --- STAGE 2: INPUT ARBITRATION ---
        // Iterate through all 4 Inputs (j)
        for (j = 0; j < 4; j = j + 1) begin
            // Check received grants in Round-Robin order starting from ptr_in[j]
            for (k = 0; k < 4; k = k + 1) begin
                search_idx = (ptr_in[j] + k) % 4;                                     //from which output port it should start searching

// Check if Output 'search_idx' granted access to Input 'j'  
                if (stage1_grant[search_idx][j] && !stage2_has_accept[j]) begin      //checking if output search_idx had given grant for input j and earlier not accepted
                    // Accepted!
                    stage2_has_accept[j] = 1;
                    stage2_chosen[j]     = search_idx;

                    // 1. Set the global grant signal for the specific VOQ(which is going to VOQ)
                    grant_signals[j * 4 + search_idx] = 1;                           // of input j going to output search_idx has been granted

                    
                    // 2. Configure Crossbar Control
                    // "search_idx" is the Output Port. "j" is the Input Source.
                    // We use "indexed part-select" (+:) to write to the correct 2 bits.
                    xbar_control[ (search_idx * 2) +: 2 ] = j;                       // Taking output search_idx and telling that it should be connected to input j
                end
            end
        end
    end
    

    // ============================================================
    // 4. SEQUENTIAL LOGIC (The Pointer Updates)
    //    Moves the pointers only if a transaction succeeded
    // ============================================================
    integer i; // distinct loop variable for sequential block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset Pointers
            for (i = 0; i < 4; i = i + 1) begin
                ptr_out[i] <= 2'b00;                              
                ptr_in[i]  <= 2'b00;
            end
        end else begin
            // Update Output Pointers
            for (i = 0; i < 4; i = i + 1) begin
                if (stage1_has_grant[i]) begin                    // only if output i has granted
                    // Move pointer to (Winner + 1) % 4
                    ptr_out[i] <= (stage1_winner[i] + 1) % 4;
                end
            end

            // Update Input Pointers
            for (i = 0; i < 4; i = i + 1) begin
                if (stage2_has_accept[i]) begin                   // only if input i has been accepted
                    // Move pointer to (Chosen Output + 1) % 4
                    ptr_in[i] <= (stage2_chosen[i] + 1) % 4; 
                end
            end
        end
    end

endmodule

//crossbar

module crossbar_4by4 (
    // Inputs from the Input Ports (The Data)
    input  wire [7:0] data_in_0,
    input  wire [7:0] data_in_1,
    input  wire [7:0] data_in_2,
    input  wire [7:0] data_in_3,

    // Control Signal from the Arbiter
    // 8 bits total: 2 bits per output port
    input  wire [7:0]  xbar_control,
    input  wire [3:0]  out_valid,

    // Outputs to the World
    output reg  [7:0] data_out_0,
    output reg  [7:0] data_out_1,
    output reg  [7:0] data_out_2,
    output reg  [7:0] data_out_3
);

    // ============================================================
    // THE SWITCHING LOGIC (Multiplexers)
    // ============================================================
    // For every output, we look at its specific 2 bits of control
    // and decide which input to listen to.
    
    // ----------------------------------------
    // Output Port 0 Logic
    // Control Bits: [1:0]
    // ----------------------------------------
    always @(*) begin
        if (out_valid[0]) begin  // CHECK VALIDITY
            case (xbar_control[1:0])
                2'b00: data_out_0 = data_in_0;
                2'b01: data_out_0 = data_in_1;
                2'b10: data_out_0 = data_in_2;
                2'b11: data_out_0 = data_in_3;
            endcase
        end else begin
            data_out_0 = 8'd0; // FORCE ZERO IF INVALID
        end
    end
    // ----------------------------------------
    // Output Port 1 Logic
    // Control Bits: [3:2]
    // ----------------------------------------
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
    

    // ----------------------------------------
    // Output Port 2 Logic
    // Control Bits: [5:4]
    // ----------------------------------------
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

    // ----------------------------------------
    // Output Port 3 Logic
    // Control Bits: [7:6]
    // ----------------------------------------
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
