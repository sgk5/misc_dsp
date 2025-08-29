//! @title Auto Gain Control (AGC) module
//! The automatic gain controller (AGC) block adaptively adjusts its gain to achieve a constant signal level at the output.
//! Based on https://www.mathworks.com/help/comm/ref/agc.html

module AGC_matlab #(
    //! Parameter defines does moving average in level estimator use ram, 1'b0 - use shift regs based on LUT, 1'b1 - use block RAM
    parameter  bit          LeMaUseRam  = 1'b0,
    //! Moving average depth in level estimator
    parameter  int unsigned LeMaDepth   = 16,
    //! Optimisation partameter, amount of bits to reduce on the output of the diff accumulator
    parameter  int unsigned AccDec      = 2,
    //
    // Exponent module parameters
    //! exponent module power width
    parameter  int unsigned ExpPwrWidth = 9,
    //! exponent module data output width
    parameter  int unsigned ExpOutWidth = 24,
    //! exponent module fractional part width
    parameter  int unsigned ExpPwrFract = 6,
    //! exponent module width of output data fractional part
    parameter  int unsigned ExpOutFract = 16,
    //! exponent module output clip level
    parameter  real         ExpClipLvl  = 50,
    //
    //! Logaritm module parameters
    //! ln input data width
    parameter  int unsigned LnInWidth   = 16,
    //! ln input argument integer part step, a power of two, 
    //! So input changes with a step of 2**step_in
    //! If not equal to 1, then in_fract must be equal to 0
    parameter  int unsigned LnStepIn    = 5,
    //! ln ouput width
    parameter  int unsigned LnOutWidth  = 16,
    //! ln input fractional part width
    parameter  int unsigned LnInFract   = 0,
    //! ln fractional part width
    parameter  int unsigned LnOutFract  = 11,
    //
    // Data width, 2 most significant (MS) bytes-i (real), 2 least significant (LS) bytes - q(im)
    localparam int unsigned DataWidth   = 32,
    // Configuration bus width
    localparam int unsigned CfgBusWidth = 32

) (
    //! rest input, synchronous active high
    input                          rst,
    //! system clock
    input                          sys_clk,
    //
    //! @virtualbus Slave_AXIs_data_input @dir in input axi stream
    //! 2 MS bytes-i (real), 2 LS bytes - q(im)
    input        [  DataWidth-1:0] saxis_in_d_tdata,
    input                          saxis_in_d_tvalid,
    //! @end
    //
    //! @virtualbus Slave_AXIs_NCO_cfg @dir in configuration axi stream, NCO configuration
    input        [CfgBusWidth-1:0] saxis_nco_tdata,
    input                          saxis_nco_tvalid,
    //! @end
    //
    //! @virtualbus Slave_AXIs_Step_size @dir in configuration axi stream, Step size
    input        [CfgBusWidth-1:0] saxis_alfa_tdata,
    input                          saxis_alfa_tvalid,
    //! @end
    //
    //! @virtualbus Slave_AXIs_Ref_cfg @dir in configuration axi stream natural logarithm of reference level
    input        [CfgBusWidth-1:0] saxis_ref_tdata,
    input                          saxis_ref_tvalid,
    //! @end
    //
    //! @virtualbus Master_AXIs_output_data @dir out Output axi stream, 2 MS bytes-i (real), 2 LS bytes - q(im)
    output logic [  DataWidth-1:0] maxis_out_d_tdata,
    output logic                   maxis_out_d_tvalid = 1'b0
    //!@end
);

    // Level estimation module data width
    localparam int unsigned LeDataWidth = DataWidth / 2;

    wire                   clk = sys_clk;
    wire [LeDataWidth-1:0] le_tdata;
    wire                   le_tvalid;

    level_estimator #(
        .UseRam     (LeMaUseRam),
        .DataWidth  (LeDataWidth),
        .DataDepth  (LeMaDepth),
        .CfgBusWidth(CfgBusWidth)
    ) Lvl_est (
        .rst               (rst),
        .sys_clk           (sys_clk),
        .saxis_in_d_tvalid (saxis_in_d_tvalid),
        .saxis_in_d_tdata  (saxis_in_d_tdata),
        .saxis_nco_tdata   (saxis_nco_tdata),
        .saxis_nco_tvalid  (saxis_nco_tvalid),
        .maxis_out_d_tdata (le_tdata),
        .maxis_out_d_tvalid(le_tvalid)
    );

    logic        [ExpOutWidth-1:0] e_out;
    logic        [  LnInWidth-1:0] log_in = '0;
    logic signed [ LnOutWidth-1:0] log_out;

    localparam int unsigned MultExpLeWidth = ExpOutWidth + LeDataWidth;
    localparam int unsigned MinusLsbNum = LnInWidth + ExpOutFract;
    // multiplication of exp and level estimator output
    wire [          MultExpLeWidth-1:0] mult_e_le;
    wire [MultExpLeWidth-1:MinusLsbNum] m_minus;

    assign mult_e_le = le_tdata * e_out;
    assign m_minus   = mult_e_le[MultExpLeWidth-1:MinusLsbNum];

    // determines clip
    always_ff @(posedge clk) begin
        if (~|m_minus == 1'b1) log_in <= mult_e_le[MinusLsbNum-1:ExpOutFract];
        else log_in <= {$size(log_in) {1'b1}};
    end

    log_nat_tabular #(
        .InWidth (LnInWidth),
        .StepIn  (LnStepIn),
        .OutWidth(LnOutWidth),
        .InFract (LnInFract),
        .OutFract(LnOutFract)
    ) ln_inst (
        .sys_clk(sys_clk),
        .log_in (log_in),
        .log_out(log_out)
    );

    // logarithm of reference level
    logic signed [LnOutWidth-1:0] ref_reg = '0;
    always_ff @(posedge clk) begin
        if (saxis_ref_tvalid == 1'b1) ref_reg <= saxis_ref_tdata[$left(ref_reg):0];
    end

    // error (difference of ln and ref)
    wire signed  [  LnOutWidth:0] diff_ref_ln_temp;
    wire         [           1:0] diff_ref_ln_msb;
    logic signed [LnOutWidth-1:0] diff_ref_ln = '0;

    assign diff_ref_ln_temp = ref_reg - log_out;
    assign diff_ref_ln_msb  = diff_ref_ln_temp[LnOutWidth-:2];

    always_ff @(posedge clk) begin
        case (diff_ref_ln_msb)
            2'b01:   diff_ref_ln <= {1'b0, {(LnOutWidth - 1) {1'b1}}};
            2'b10:   diff_ref_ln <= {1'b1, {(LnOutWidth - 1) {1'b0}}};
            default: diff_ref_ln <= diff_ref_ln_temp[LnOutWidth-1:0];
        endcase
    end

    localparam int unsigned AregWidth = 8;

    logic [AregWidth-1:0] a_reg = '0;
    always_ff @(posedge clk) begin
        if (saxis_alfa_tvalid) a_reg <= saxis_alfa_tdata[AregWidth-1:0];
    end

    wire signed [AregWidth:0] a_sign = {1'b0, a_reg};

    localparam int unsigned MultAregWidth = AregWidth + LnOutWidth + 1;

    logic signed [MultAregWidth-1:0] mult_a_d = '0;
    logic signed [MultAregWidth-1:0] buf_m = '0;

    wire signed [$size(buf_m):0] sum_temp;
    wire [$left(sum_temp):$left(sum_temp)-1-AccDec] sum_temp_minus;

    assign sum_temp       = buf_m + mult_a_d;
    assign sum_temp_minus = sum_temp[$left(sum_temp):$left(sum_temp)-1-AccDec];

    always_ff @(posedge clk) begin
        mult_a_d <= diff_ref_ln * a_sign;
        if (rst == 1'b1) buf_m <= '0;
        else if (le_tvalid == 1'b1) begin
            if ((~|sum_temp_minus || &sum_temp_minus) == 1'b1) begin
                buf_m <= sum_temp[MultAregWidth-1:0];
            end else begin
                buf_m <= (sum_temp[$left(sum_temp)]) ?
                    {1'b1, {(MultAregWidth - 1) {1'b0}}} : {1'b0, {(MultAregWidth - 1) {1'b1}}};
            end
        end
    end

    localparam int unsigned LowerIndex = AregWidth - (ExpPwrFract - LnOutFract);
    localparam int unsigned UpperIndex = LowerIndex + ExpPwrWidth - 1;
    logic signed [           ExpPwrWidth-1:0] e_pwr = '0;

    wire         [MultAregWidth-1:UpperIndex] b_minus;

    assign b_minus = buf_m[MultAregWidth-1:UpperIndex];

    always_ff @(posedge clk)
        if ((~|b_minus || &b_minus) == 1'b1) e_pwr <= buf_m[UpperIndex : LowerIndex];
        else begin
            e_pwr <= {buf_m[MultAregWidth-1], {(ExpPwrWidth - 1) {~buf_m[MultAregWidth-1]}}};
        end

    exponenta_tabular #(
        .ExpPwrWidth (ExpPwrWidth),
        .ExpOutWidth (ExpOutWidth),
        .ExpPwrFract (ExpPwrFract),
        .ExpOutFract (ExpOutFract),
        .ExpClipLevel(ExpClipLvl)
    ) Exp_inst (
        .sys_clk  (sys_clk),
        .exp_power(e_pwr),
        .exp_out  (e_out)
    );

    localparam int unsigned PreDataWidth = ExpOutWidth + DataWidth / 2 + 1;

    logic signed [              ExpOutWidth : 0] e_sign;
    logic signed [             PreDataWidth-1:0] i_data;
    logic signed [             PreDataWidth-1:0] q_data;
    logic        [(ExpOutWidth-ExpOutFract-1):0] ei_minus;
    logic        [(ExpOutWidth-ExpOutFract-1):0] eq_minus;

    always_comb begin
        e_sign   = {1'b0, e_out};
        i_data   = e_sign * signed'(saxis_in_d_tdata[DataWidth/2+:DataWidth/2]);
        q_data   = e_sign * signed'(saxis_in_d_tdata[0+:DataWidth/2]);
        ei_minus = i_data[PreDataWidth-1:(DataWidth/2+ExpOutFract-1)];
        eq_minus = q_data[PreDataWidth-1:(DataWidth/2+ExpOutFract-1)];
    end

    always_ff @(posedge clk) begin
        if (rst == 1'b1) maxis_out_d_tvalid <= 1'b0;
        else maxis_out_d_tvalid <= saxis_in_d_tvalid;
    end

    always_ff @(posedge clk) begin
        if ((~|ei_minus || &ei_minus) == 1'b1) begin
            maxis_out_d_tdata[DataWidth-1:DataWidth/2] <= i_data[ExpOutFract+:DataWidth/2];
        end else begin
            maxis_out_d_tdata[DataWidth-1] <= i_data[PreDataWidth-1];
            maxis_out_d_tdata[DataWidth-2: DataWidth/2] <= {(DataWidth/2-1){~i_data[PreDataWidth-1]}};
        end
    end

    always_ff @(posedge clk) begin
        if ((~|eq_minus || &eq_minus) == 1'b1) begin
            maxis_out_d_tdata[0+:DataWidth/2] <= q_data[ExpOutFract+:DataWidth/2];
        end else begin
            maxis_out_d_tdata[DataWidth/2-1]   <= q_data[PreDataWidth-1];
            maxis_out_d_tdata[DataWidth/2-2:0] <= {(DataWidth / 2 - 1) {~q_data[PreDataWidth-1]}};
        end
    end

endmodule
