//! @title Natural logarithm ROM module
//! ROM with automatic value generation. <br>
//! Designed for AGC (Automatic Gain Control). <br>
//! Input data is unsigned number in the following format: <br>
//! *(InWidth-InFract)* bits for the integer part, *(InFract)* bits for the fractional part. <br>
//! The output is signed: <br>
//! 1 bit for the sign, *(OutWidth-OutFract-1)* bits for the integer part, and *(OutFract)* bits for the fractional part.

module log_nat #(
    //! Module input width
    parameter int unsigned InWidth  = 16,
    //! ln input argument integer part step, a power of two,
    //! So input changes with a step of 2**StepIn
    //! If not equal to 1, then InFract must be equal to 0
    parameter int unsigned StepIn   = 5,
    //! Module ouput width
    parameter int unsigned OutWidth = 16,
    //! Input fractional part width
    parameter int unsigned InFract  = 0,
    //! Output fractional part width
    parameter int unsigned OutFract = 11
) (
    //! clock
    input                              sys_clk,
    //! Input data, fixed point
    input  unsigned     [ InWidth-1:0] log_in,
    //! Natural log of input data
    output logic signed [OutWidth-1:0] log_out
);

    initial begin
        if (StepIn != 1 && InFract != 0) begin
            $error("Error in log_nat.sv! If StepIn != 1 then InFract must be 0!");
        end
    end

    typedef logic unsigned [OutWidth-1:0] array2d_t[2**(InWidth-StepIn)];

    (* rom_style="block" *)
    array2d_t                        values;
    wire unsigned [InWidth-1:StepIn] addr;

    initial begin
        values = log_values();
    end

    assign addr = log_in[InWidth-1:StepIn];

    always_ff @(posedge sys_clk) log_out <= values[addr];

    function automatic array2d_t log_values;
        automatic real den = (2 ** InFract);
        automatic real nom = (2 ** OutFract);
        automatic real pwr_r;
        automatic real log;
        foreach (log_values[i]) begin
            pwr_r = real'(i) * real'(2 ** StepIn) / real'(den);
            log = ($ln(pwr_r) * real'(nom));
            log_values[i] = int'(log);
        end
    endfunction

endmodule
