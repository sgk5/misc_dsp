//! @title Moving average module
//! The moving average module utilizes the ternary addition feature of Xilinx FPGAs.
//! The internal shift register can be implemented using either BRAM or LUT.

module mov_avg #(
    //! 0 - use shift registers, 1 - use ram
    parameter bit          UseRam    = 0,
    //! Data width
    parameter int unsigned DataWidth = 16,
    //! Buffer depth, number of points over which averaging occurs
    parameter int unsigned DataDepth = 16
) (
    //! system clock signal
    input                               clk,
    //! input synchronous reset signal, active high
    input                               rst,
    //! @virtualbus SAXIS_input_data @dir in input axis data stream
    input  signed       [DataWidth-1:0] saxis_in_d_tdata,
    input                               saxis_in_d_tvalid,
    //! @end
    //! @virtualbus MAXIS_output_data @dir out output data stream
    output logic signed [DataWidth-1:0] maxis_out_d_tdata,
    output logic                        maxis_out_d_tvalid
    //! @end
);

    logic signed [DataWidth-1:0] saxis_sh_reg_tdata;
    logic                        saxis_sh_reg_tvalid;

    logic signed [DataWidth-1:0] maxis_sh_reg_tdata;
    logic                        maxis_sh_reg_tvalid;

    logic signed [DataWidth-1:0] in_buf;

    always_comb begin
        saxis_sh_reg_tdata  = saxis_in_d_tdata;
        saxis_sh_reg_tvalid = saxis_in_d_tvalid;
    end

    generate
        if (UseRam == 1'b1) begin : gen_RAM

            always_ff @(posedge clk) begin
                in_buf <= saxis_in_d_tdata;
            end

            localparam int unsigned AdWidth = $clog2(DataDepth);
            (* ram_style="block" *)
            logic [DataWidth-1:0] sh_reg     [DataDepth] = '{default: '0};
            logic [  AdWidth-1:0] ad = '0;
            logic [DataWidth-1:0] out_d = '0;

            always_ff @(posedge clk) begin : ProcShReg
                if (saxis_sh_reg_tvalid == 1'b1) sh_reg[ad] <= saxis_sh_reg_tdata;
            end : ProcShReg

            always_ff @(posedge clk) begin : ProcAd
                if (rst == 1'b1) ad <= '0;
                else if (saxis_sh_reg_tvalid == 1'b1) begin
                    if (ad < DataDepth - 1) ad <= ad + 1;
                    else ad <= '0;
                end
            end : ProcAd

            always_ff @(posedge clk) begin
                maxis_sh_reg_tvalid <= saxis_sh_reg_tvalid;
            end

            always_ff @(posedge clk) begin
                out_d <= sh_reg[ad];
            end

            always_comb maxis_sh_reg_tdata = out_d;

        end : gen_RAM

        else begin : gen_reg

            always_comb in_buf = saxis_in_d_tdata;

            logic signed [DataWidth-1:0] sh_reg[DataDepth] = '{default: '0};

            always_ff @(posedge clk) begin : ProcShReg
                if (saxis_sh_reg_tvalid) begin
                    sh_reg[1:DataDepth-1] <= sh_reg[0:DataDepth-2];
                    sh_reg[0] <= saxis_sh_reg_tdata;
                end
            end : ProcShReg

            always_comb maxis_sh_reg_tdata = sh_reg[DataDepth-1];

            always_comb maxis_sh_reg_tvalid = saxis_sh_reg_tvalid;

        end : gen_reg

    endgenerate

    localparam int unsigned MovAvgSumWidth = DataWidth + $clog2(DataDepth);

    logic signed [MovAvgSumWidth-1:0] mov_avg_sum = '0;

    always_ff @(posedge clk) begin : ProcSum
        if (rst == 1'b1) mov_avg_sum <= '0;
        else if (maxis_sh_reg_tvalid == 1'b1) begin
            mov_avg_sum <= mov_avg_sum + in_buf - maxis_sh_reg_tdata;
        end
    end : ProcSum

    always_comb maxis_out_d_tdata = mov_avg_sum[(MovAvgSumWidth-1)-:DataWidth];

    always_ff @(posedge clk) begin
        maxis_out_d_tvalid <= maxis_sh_reg_tvalid;
    end

endmodule
