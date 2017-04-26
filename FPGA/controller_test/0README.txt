This is a synthesis project for test the SPI Controller core using the Avnet
Spartan 3A Evaluation Kit board.

Using the SPI Controller, the Top Level reads the ID of S25FL Flash SPI memory
periodically (once a second) and checks the result. The status of the
operation are reported through the LEDs in the board, using the following
codes:

OK   = "1111" (reading ok)
BAD  = "0110" (bad reading)
INIT = "0001" (reading inited)
BUSY = "0010" (controller busy)


To communicate with memory, besides of the lines for SPI, the following lines
are driven:

* fshce_o : Flash_CE of the board. When high, enables communication between
FPGA and memory (Chip enable of MUX U20).

* sfhld_o : Hold# pin of the S25FL. When low, pauses any communication with
the memory.