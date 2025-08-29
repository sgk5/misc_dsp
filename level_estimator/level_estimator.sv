//! @title Module for calculating the level of a complex signal
//! Module based on the alpha max beta min algorithm. <br>
//! More about algoritm https://en.wikipedia.org/wiki/Alpha_max_plus_beta_min_algorithm <br>
//! It is assumed that the data arrives at a rate exceeding the symbol rate. <br>

module level_estimator #(
    parameter int unsigned UseRam      = 0,
    parameter int unsigned DataWidth   = 32,
    parameter int unsigned DataDepth   = 16,
    parameter int unsigned CfgBusWidth = 32
) (
    //! rest input, synchronous active high
    input                          rst,
    //! system clock
    input                          sys_clk,
    //
    //! @virtualbus Slave_AXIs_data_input @dir in input axi stream, upper half is I, lower half is Q
    input        [  DataWidth-1:0] saxis_in_d_tdata,
    input                          saxis_in_d_tvalid,
    //! @end
    //
    //! @virtualbus Slave_AXIs_NCO_cfg @dir in configuration axi stream, NCO configuration
    input        [CfgBusWidth-1:0] saxis_nco_tdata,
    input                          saxis_nco_tvalid,
    //! @end
    //
    //! @virtualbus Master_AXIs_output_data @dir out Output axi stream, 2 bytes unsigned
    output logic [DataWidth/2-1:0] maxis_out_d_tdata,
    output logic                   maxis_out_d_tvalid
    //!@end
);

    wire clk = sys_clk;

    wire strobe_out;

    localparam int unsigned NcoWidth = 24;
    // initial fout will be 1/8 clk
    localparam int unsigned NcoStepInit = 2 ** (NcoWidth - 4);

    nco #(
        .NcoWidth   (NcoWidth),
        .NcoStepInit(NcoStepInit)
    ) nco_axis_inst (
        .rst             (rst),
        .clk             (clk),
        .saxis_nco_tdata (saxis_nco_tdata),
        .saxis_nco_tvalid(saxis_nco_tvalid),
        .strobe_out      (strobe_out)
    );

    localparam int unsigned AbsDataWidth = DataWidth / 2 - 1;

    logic [AbsDataWidth-1 : 0] i_buf = '0;
    logic [AbsDataWidth-1 : 0] q_buf = '0;

    always_ff @(posedge clk) begin : proc_abs
        if (saxis_in_d_tvalid) begin
            if (saxis_in_d_tdata[DataWidth-1] == 1'b1) begin
                if (|saxis_in_d_tdata[DataWidth/2+:(AbsDataWidth)] == 1'b0) begin
                    i_buf <= '1;
                end else begin
                    i_buf <= !saxis_in_d_tdata[DataWidth/2+:(AbsDataWidth)] + 1'b1;
                end
            end else begin
                i_buf <= saxis_in_d_tdata[DataWidth/2+:(AbsDataWidth)];
            end

            if (saxis_in_d_tdata[DataWidth/2-1] == 1'b1) begin
                if (|saxis_in_d_tdata[0+:(AbsDataWidth)] == 1'b0) begin
                    q_buf <= '1;
                end else begin
                    q_buf <= !saxis_in_d_tdata[0+:(AbsDataWidth)] + 1'b1;
                end
            end else begin
                q_buf <= saxis_in_d_tdata[0+:(AbsDataWidth)];
            end
        end
    end

    logic val_sh = '0;
    always_ff @(posedge clk) val_sh <= saxis_in_d_tvalid && strobe_out;

    wire                        i_ma_tvalid;
    wire                        q_ma_tvalid;
    wire [DataWidth / 2 -1 : 0] i_ma_tdata;
    wire [DataWidth / 2 -1 : 0] q_ma_tdata;

    mov_avg #(
        .UseRam   (UseRam),
        .DataWidth(DataWidth / 2),
        .DataDepth(DataDepth)
    ) Mov_Av_I (
        .rst               (rst),
        .clk               (clk),
        //input axis data stream
        .saxis_in_d_tdata  ({1'b0,i_buf}),
        .saxis_in_d_tvalid (val_sh),
        //output data stream
        .maxis_out_d_tdata (i_ma_tdata),
        .maxis_out_d_tvalid(i_ma_tvalid)
    );

    mov_avg #(
        .UseRam   (UseRam),
        .DataWidth(DataWidth / 2),
        .DataDepth(DataDepth)
    ) Mov_Av_Q (
        .rst               (rst),
        .clk               (clk),
        //input axis data stream
        .saxis_in_d_tdata  ({1'b0,q_buf}),
        .saxis_in_d_tvalid (val_sh),
        //output data stream
        .maxis_out_d_tdata (q_ma_tdata),
        .maxis_out_d_tvalid(q_ma_tvalid)
    );

    logic [AbsDataWidth-1 : 0] min = '0;
    logic [AbsDataWidth-1 : 0] max = '0;

    always_ff @(posedge clk)
        //0 cycle
        if (i_ma_tdata > q_ma_tdata) begin
            min <= q_ma_tdata;
            max <= i_ma_tdata;
        end else begin
            min <= i_ma_tdata;
            max <= q_ma_tdata;
        end

    logic [AbsDataWidth-1 : 0] mult_z0_0 = '0;
    logic [AbsDataWidth-1 : 0] mult_z0_1 = '0;
    logic [AbsDataWidth-1 : 0] z_0 = '0;
    logic [AbsDataWidth-1 : 0] mult_z1_0;
    logic [AbsDataWidth-1 : 0] mult_z1_1;
    logic [AbsDataWidth-1 : 0] z_1;
    logic [AbsDataWidth-1 : 0] z_overall = '0;

    always_ff @(posedge clk) begin
        //alfa0*max; alfa0=127/128
        mult_z0_0 <= max - max / 128;
        //beta0*min; //1 //beta0=3/16
        mult_z0_1 <= min / 8 + min / 16;
        //alfa1*max; //alfa1=27/32
        mult_z1_0 <= max - max / 8 - max / 32;
        //beta1*min; //1 //beta1=71/128 
        mult_z1_1 <= min / 2 + min / 16 - min / 128;
        //2 cycle
        z_0 <= mult_z0_0 + mult_z0_1;
        //2 cycle 
        z_1 <= mult_z1_0 + mult_z1_1;
        //3 cycle 
        z_overall <= (z_0 > z_1) ? z_0 : z_1;
    end

    logic [3:0] val_out_sh = '0;
    always_ff @(posedge clk) begin
        if (rst == 1'b1) val_out_sh <= 1'b0;
        else val_out_sh <= {val_out_sh, i_ma_tvalid};
    end

    assign maxis_out_d_tvalid = val_out_sh[$left(val_out_sh)];
    assign maxis_out_d_tdata  = {1'b0, z_overall};

endmodule
