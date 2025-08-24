
# Entity: exponenta_tabular 
- **File**: exponenta_tabular.sv
- **Title:**  Natural logarithm ROM module

## Diagram
![Diagram](exponenta_tabular.svg "Diagram")
## Description

ROM with automatic value generation. <br>
Designed for AGC (Automatic Gain Control). <br>
Input data is signed number in the following format: <br>
1 bit for the sign, *(ExpPwrWidth-ExpPwrFract-1)* bits for the integer part, *(ExpPwrFract)* bits for the fractional part. <br>
The output is unsigned: <br>
*(ExpOutWidth-ExpOutFract-1)* bits for the integer part, and *(ExpOutFract)* bits for the fractional part.

## Generics

| Generic name | Type         | Value | Description                                   |
| ------------ | ------------ | ----- | --------------------------------------------- |
| ExpPwrWidth  | int unsigned | 9     | Exponent input data width (power of exponent) |
| ExpOutWidth  | int unsigned | 24    | Exponent output data width(e**in_data value)  |
| ExpPwrFract  | int unsigned | 6     | Exponent input data fractional part width     |
| ExpOutFract  | int unsigned | 16    | Exponent output data fractional part width    |
| ExpClipLevel | real         | 255   | Exponent output value clip level              |

## Ports

| Port name | Direction | Type                             | Description                             |
| --------- | --------- | -------------------------------- | --------------------------------------- |
| sys_clk   | input     |                                  | clock signal                            |
| exp_power | input     | signed         [ExpPwrWidth-1:0] | Exponent input data (power of exponent) |
| exp_out   | output    | [ExpOutWidth-1:0]                | Exponent output data (e**in_data value) |
