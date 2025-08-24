
# Entity: log_nat 
- **File**: log_nat.sv
- **Title:**  Natural logarithm ROM module

## Diagram
![Diagram](log_nat.svg "Diagram")
## Description

ROM with automatic value generation. <br>
Designed for AGC (Automatic Gain Control). <br>
Input data is unsigned number in the following format: <br>
*(InWidth-InFract)* bits for the integer part, *(InFract)* bits for the fractional part. <br>
The output is signed: <br>
1 bit for the sign, *(OutWidth-OutFract-1)* bits for the integer part, and *(OutFract)* bits for the fractional part.

## Generics

| Generic name | Type         | Value | Description                                                                                                                                         |
| ------------ | ------------ | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| InWidth      | int unsigned | 16    | Module input width                                                                                                                                  |
| StepIn       | int unsigned | 5     | ln input argument integer part step, a power of two,  So input changes with a step of 2**StepIn  If not equal to 1, then InFract must be equal to 0 |
| OutWidth     | int unsigned | 16    | Module ouput width                                                                                                                                  |
| InFract      | int unsigned | 0     | Input fractional part width                                                                                                                         |
| OutFract     | int unsigned | 11    | Output fractional part width                                                                                                                        |

## Ports

| Port name | Direction | Type                        | Description               |
| --------- | --------- | --------------------------- | ------------------------- |
| sys_clk   | input     |                             | clock                     |
| log_in    | input     | unsigned     [ InWidth-1:0] | Input data, fixed point   |
| log_out   | output    | [OutWidth-1:0]              | Natural log of input data |
