
# Entity: nco 
- **File**: nco.sv
- **Title:**  Numeracally controlled oscilator

## Diagram
![Diagram](nco.svg "Diagram")
## Description

A customizable, simple NCO with a strobe at the output. <br>
Output frequency can be changed dynamically.<br>
The frequency is determined by the following formula: <br>
**`F_out=(F_clk/2**NcoWidth)*NCO_CODE`**

## Generics

| Generic name | Type         | Value           | Description    |
| ------------ | ------------ | --------------- | -------------- |
| NcoWidth     | int unsigned | 24              | main cnt width |
| NcoStepInit  | int unsigned | 2**(NcoWidth-4) | initial value  |

## Ports

| Port name          | Direction | Type        | Description                                 |
| ------------------ | --------- | ----------- | ------------------------------------------- |
| rst                | input     |             | active high synchronous reset               |
| clk                | input     |             | system clock                                |
| strobe_out         | output    |             | output frequency strobe                     |
| Slave_AXIs_NCO_cfg | in        | Virtual bus | configuration axi stream, NCO configuration |

### Virtual Buses

#### Slave_AXIs_NCO_cfg

| Port name        | Direction | Type             | Description |
| ---------------- | --------- | ---------------- | ----------- |
| saxis_nco_tdata  | input     | [NcoWidth-1 : 0] |             |
| saxis_nco_tvalid | input     |                  |             |
