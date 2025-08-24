//! @title Natural logarithm ROM module
//! ROM with automatic value generation. <br>
//! Designed for AGC (Automatic Gain Control). <br>
//! Input data is signed number in the following format: <br>
//! 1 bit for the sign, *(ExpPwrWidth-ExpPwrFract-1)* bits for the integer part, *(ExpPwrFract)* bits for the fractional part. <br>
//! The output is unsigned: <br>
//! *(ExpOutWidth-ExpOutFract-1)* bits for the integer part, and *(ExpOutFract)* bits for the fractional part.

module exponenta_tabular #(
    //! Exponent input data width (power of exponent)
    parameter int unsigned ExpPwrWidth = 9,
    //! Exponent output data width(e**in_data value)
    parameter int unsigned ExpOutWidth = 24,
    //! Exponent input data fractional part width
    parameter int unsigned ExpPwrFract = 6,
    //! Exponent output data fractional part width
    parameter int unsigned ExpOutFract = 16,
    //! Exponent output value clip level
    parameter real ExpClipLevel = 255
) (
    //! clock signal
    input                                   sys_clk,
    //! Exponent input data (power of exponent)
    input  signed         [ExpPwrWidth-1:0] exp_power,
    //! Exponent output data (e**in_data value)
    output logic unsigned [ExpOutWidth-1:0] exp_out
);

    typedef logic unsigned [ExpOutWidth-1:0] array2d_t[2**ExpPwrWidth];

    (* rom_style="block" *)
    array2d_t values;

    initial begin
        values = exponenta_values();
    end

    wire unsigned [ExpPwrWidth-1:0] addr;

    assign addr = exp_power - 2 ** (ExpPwrWidth - 1);

    always_ff @(posedge sys_clk) exp_out <= values[addr];

    function automatic array2d_t exponenta_values;
        automatic real den = (2 ** ExpPwrFract);
        automatic real nom = (2 ** ExpOutFract);
        automatic bit signed [ExpPwrWidth-1:0] pwr_s;
        automatic real pwr_r;
        automatic real exponenta;
        foreach (exponenta_values[i]) begin
            pwr_s = signed'(i - 2 ** (ExpPwrWidth - 1));
            pwr_r = real'(pwr_s) / real'(den);
            exponenta = ($exp(pwr_r) * real'(nom));
            if (exponenta > (ExpClipLevel * real'(nom)))
                exponenta_values[i] = int'(ExpClipLevel * real'(nom));
            else exponenta_values[i] = int'(exponenta);
        end
    endfunction

endmodule
