//! @title Numeracally controlled oscilator
//! A customizable, simple NCO with a strobe at the output. <br>
//! Output frequency can be changed dynamically.<br>
//! The frequency is determined by the following formula: <br>
//! **`F_out=(F_clk/2**NcoWidth)*NCO_CODE`**

module nco #(
    //!  main cnt width
    parameter int unsigned NcoWidth    = 24,
    //! initial value
    parameter int unsigned NcoStepInit = 2**(NcoWidth-4)
) (
    //! active high synchronous reset
    input rst,
    //! system clock
    input clk,

    //! @virtualbus Slave_AXIs_NCO_cfg @dir in configuration axi stream, NCO configuration
    input        [NcoWidth-1 : 0] saxis_nco_tdata,
    input                         saxis_nco_tvalid,
    //! @end
    //! output frequency strobe
    output logic                  strobe_out
);

    logic [NcoWidth-1:0] nco_step = NcoStepInit;
    logic [NcoWidth-1:0] nco_cnt = 2 ** (NcoWidth - 1) + NcoStepInit / 2;

    always_ff @(posedge clk) begin
        if (saxis_nco_tvalid) nco_step <= saxis_nco_tdata;
    end

    logic [NcoWidth-1:0] nco_cnt_rst_val = 2 ** (NcoWidth - 1) + NcoStepInit / 2;

    always_ff @(posedge clk) begin
        nco_cnt_rst_val <= 2 ** (NcoWidth - 1) + (nco_step >> 1);
    end

    always @(posedge clk)
        if (rst) nco_cnt <= nco_cnt_rst_val;
        else nco_cnt <= nco_cnt + nco_step;

    logic nco_str_ff = 0;

    always @(posedge clk) begin
        if (rst) nco_str_ff <= '0;
        else nco_str_ff <= nco_cnt[$left(nco_cnt)];
    end

    always @(posedge clk) begin
        strobe_out <= ~nco_str_ff && nco_cnt[$left(nco_cnt)] && ~rst;
    end

endmodule
