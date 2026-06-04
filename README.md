# APB Master-Slave Communication Protocol in Verilog

## Overview

This project implements a simplified Advanced Peripheral Bus (APB) communication system in Verilog consisting of:

- 1 APB Master
- 2 APB Slaves
- Top-level integration module
- Self-checking testbench

The master initiates read and write transactions, while the slaves respond based on address decoding.

---

## Project Structure

```text
.
├── apb_master.v
├── apb_slave.v
├── apb_slave2.v
├── apb_top.v
├── apb_tb.v
└── README.md
```

---

## Architecture

```text
                +----------------+
                |   APB Master   |
                +-------+--------+
                        |
                        |
        +---------------+---------------+
        |                               |
        | PSEL1 = 0                     | PSEL1 = 1
        |                               |
+-------v--------+             +--------v-------+
|   APB Slave    |             |   APB Slave2   |
|  (3-State FSM) |             |  (4-State FSM) |
+----------------+             +----------------+
```

### Slave Selection

The MSB of the APB address determines which slave is selected.

| Address Range | Selected Slave |
|--------------|----------------|
| 0x000 - 0x0FF | APB Slave |
| 0x100 - 0x1FF | APB Slave2 |

```verilog
PSEL1 = address[8];
```

---

## APB Master

### Features

- Supports read and write transactions
- Implements APB protocol phases:
  - IDLE
  - SETUP
  - ACCESS
- Generates:
  - PADDR
  - PWDATA
  - PWRITE
  - PENABLE
  - PSEL1
- Waits for slave assertion of PREADY
- Captures read data from selected slave

### Master FSM

```text
        +------+
        | IDLE |
        +--+---+
           |
           | TRANSFER
           v
       +---+----+
       | SETUP  |
       +---+----+
           |
           v
       +---+----+
       | ACCESS |
       +---+----+
           |
     PREADY=1
           |
           +----> IDLE / SETUP
```

---

## APB Slave

### Features

- Memory size: 256 × 8-bit
- Preloaded memory contents

```verilog
memory[i] = i;
```

Example:

| Address | Data |
|----------|------|
| 0x00 | 0x00 |
| 0x01 | 0x01 |
| 0x55 | 0x55 |
| 0xAA | 0xAA |
| 0xFE | 0xFE |

### FSM

```text
IDLE
  |
  v
ACCESS
  |
  v
READY
  |
  v
IDLE
```

### Read Operation

```verilog
SLV_PRDATA = memory[PADDR];
```

### Write Operation

```verilog
memory[PADDR] = PWDATA;
```

### Response Time

- 1-cycle access latency
- PREADY asserted in READY state

---

## APB Slave2

### Features

- Same memory architecture as Slave1
- Additional wait state inserted

### FSM

```text
IDLE
  |
  v
ACCESS
  |
  v
DELAY
  |
  v
READY
  |
  v
IDLE
```

### Response Time

- Additional DELAY state
- Simulates a slower peripheral
- PREADY asserted only in READY state

---

## Memory Organization

Each slave contains:

```verilog
reg [7:0] memory [255:0];
```

### Address Width

```verilog
parameter size = 8;
```

Address map:

| Address Bit | Function |
|------------|----------|
| [8] | Slave Select |
| [7:0] | Internal Slave Address |

---

## Top Module

The top module integrates:

- APB Master
- APB Slave
- APB Slave2

### Read Data Multiplexing

```verilog
assign PRDATA =
        PSEL1 ? PRDATA1 :
                PRDATA2;
```

### Ready Multiplexing

```verilog
assign PREADY =
        PSEL1 ? PREADY1 :
                PREADY2;
```

---

## APB Signals

| Signal | Direction | Description |
|----------|------------|-------------|
| PCLK | Input | APB Clock |
| PRESETn | Input | Active-Low Reset |
| PADDR | Master → Slave | Address Bus |
| PWDATA | Master → Slave | Write Data |
| PRDATA | Slave → Master | Read Data |
| PWRITE | Master → Slave | Read/Write Control |
| PENABLE | Master → Slave | Access Phase Indicator |
| PREADY | Slave → Master | Transfer Complete |
| PSEL1 | Master → Slave | Slave Select |
| PSLVERR | Slave → Master | Error Indicator |

---

## Testbench Features

The self-checking testbench verifies:

### ROM Reads

```verilog
do_read(9'h000, 8'h00);
do_read(9'h055, 8'h55);
do_read(9'h0FE, 8'hFE);
```

### Write → Read Verification

```verilog
do_write(9'h010, 8'hBE);
do_read (9'h010, 8'hBE);
```

### Slave Selection

```text
0x000 - 0x0FF -> Slave
0x100 - 0x1FF -> Slave2
```

### Corner Cases

- Boundary addresses
- Boundary data values
- Consecutive accesses
- Long idle periods
- Multiple writes to same address
- Cross-slave independence
- Bit-pattern testing

---

## Simulation

### Compile

```bash
iverilog -o apb_sim \
apb_master.v \
apb_slave.v \
apb_slave2.v \
apb_top.v \
apb_tb.v
```

### Run

```bash
vvp apb_sim
```

### Open Waveform

```bash
gtkwave apb_tb.vcd
```

---

## Example Transaction

### Write Transaction

```text
Master
  |
  | SETUP
  | PADDR  = 0x20
  | PWDATA = 0xEF
  |
  v
ACCESS
  |
  v
Slave stores data
  |
  v
PREADY = 1
```

### Read Transaction

```text
Master
  |
  | SETUP
  | PADDR = 0x20
  |
  v
ACCESS
  |
  v
Slave returns data
  |
  v
PRDATA = 0xEF
```

---

## Expected Results

```text
============================================================
RESULTS: XX PASSED | 0 FAILED | XX TOTAL
============================================================
```

---

