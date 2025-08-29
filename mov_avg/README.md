
# Entity: mov_avg 
- **File**: mov_avg.sv
- **Title:**  Moving average module

## Diagram
![Diagram](mov_avg.svg "Diagram")
## Description

The moving average module utilizes the ternary addition feature of Xilinx FPGAs.
The internal shift register can be implemented using either BRAM or LUT.

## Generics

| Generic name | Type         | Value | Description                                                |
| ------------ | ------------ | ----- | ---------------------------------------------------------- |
| UseRam       | bit          | 0     | 0 - use shift registers, 1 - use ram                       |
| DataWidth    | int unsigned | 16    | Data width                                                 |
| DataDepth    | int unsigned | 16    | Buffer depth, number of points over which averaging occurs |

## Ports

| Port name         | Direction | Type        | Description                                 |
| ----------------- | --------- | ----------- | ------------------------------------------- |
| clk               | input     |             | system clock signal                         |
| rst               | input     |             | input synchronous reset signal, active high |
| SAXIS_input_data  | in        | Virtual bus | input axis data stream                      |
| MAXIS_output_data | out       | Virtual bus | output data stream                          |

### Virtual Buses

#### SAXIS_input_data

| Port name         | Direction | Type                         | Description |
| ----------------- | --------- | ---------------------------- | ----------- |
| saxis_in_d_tdata  | input     | signed       [DataWidth-1:0] |             |
| saxis_in_d_tvalid | input     |                              |             |
#### MAXIS_output_data

| Port name          | Direction | Type            | Description |
| ------------------ | --------- | --------------- | ----------- |
| maxis_out_d_tdata  | output    | [DataWidth-1:0] |             |
| maxis_out_d_tvalid | output    |                 |             |
