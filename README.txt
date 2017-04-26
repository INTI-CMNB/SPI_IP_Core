Copyright (c) 2010 Francisco Salomón <fsalomon@inti.gob.ar>
Copyright (c) 2010 Instituto Nacional de Tecnología Industrial

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA


Lybrary name: SPI

Usage:
library SPI;
use SPI.Devices.all;

Dependencies:
 vhdlspp
 mems
 utils

Dependencies for Testbench:
 ghdl
 utils
 wb_handler


Description:
-----------
  This is a Wishbone bus's compatible SPI Master interface. It has transmition
and reception FIFOs and status and control register (see Register below),
addressable via Wishbone bus. Besides, it has interruption request for data
arrived and overflow error.
  The SPI (Serial Periferical Interface) bus, as describes the Motorola's SPI
Block Guide (pdf:1:info/S12SPIV3.pdf), is a full-duplex synchronous channel
that supports four-wire interface (receive, transmit, clock and slave-select)
between a master and a selected slave.
  Below, configuration parameters, transaction modes and so on are described.


Available entities for this library:
-----------------------------------
  The entities defined in spi_pkg.vhdl are:
- SPI_WB: Core's main description. It contains controller, FIFOs,
interruption request generation and Wishbone interface. Its description
file is spi_wb.vhdl.
- SPI_Controller: SPI Master controller. It has no Wishbone interface nor
transaction buffers. Its description file is spi_controller.vhdl.
- S25FL_sim: Spansion Flash SPI memory S25FL simulator. It is used in
testbenchs. Its description file is testbench/s25fl_simulator.vhdl.


Testbench:
---------
  In ./testbench directory there are testbench descriptions for SPI_Controller
(spi_controller_tb.vhdl) and SPI_WB (spi_tb.vhdl). Both descriptions are not
synthesizable and it simulates transactions with a S25FL memory. For execute
it, use make command from main directory.


Generics:
--------
- FIFO_DEPTH: [natural] Depth of transmition and reception FIFOs; must be less
than or equal to 2^FIFO_ADDR_W.
- FIFO_ADDR_W: [natural] Transmition and reception FIFOs address bus's width:
must be greater than or equal to  log_2(FIFO_DEPTH).
- SCLK_PHASE: [std_logic] Serial clock phase. With SCLK_POLARITY, it
determines the transaction's mode.
- SCLK_POLARITY:[std_logic] Serial clock polarity. With SCLK_PHASE, it
determines the transaction's mode.
- SLAVE_QTT: [positive] Slaves quantity, it means number of external lines for
slave selection.
- SS_BITS_QTT: [positive] Bits quantity for slave selection.
- MSB_IS_FIRST: [boolean] If true, most significant bit is sent first.
- DR_IRQ_ALWS: [boolean] If true, controller requests interrupt for each data
ready event.
- DATA_W: [positive] Width for data bus, FIFOs and transaction size.


Registers:
---------
By default are all 8 bit, but this is configurable through DATA_W generic.
 -------------------------------------------------------------------------
|  Register   | Address |  Mode |                 Content                 |
--------------------------------------------------------------------------
| tx_fifo_in  |  0      | Write |           (data to transmit)            |
| rx_fifo_out |  0      | Read  |             (data received)             |
|  control    |  1      | Write | x|.. | x    |   ss |     ...      |ss   |
|  status     |  1      | Read  | x|x|x|oer_tx|oer_rx|rx_rdy|tx_free|busy |
 -------------------------------------------------------------------------

- tx_fifo_in: writing address of tx FIFO

- rx_fifo_out: reading address of rx FIFO

- control:
   x: reserved
   s: slave selection bits; its queantity depends on the SS_BITS_QTT generic

- status:
   x: reserved
   oer_tx: indicates tx FIFO overflow
   oer_tx: indicates overflow rx FIFO
   rx_rdy: indicates data available in rx FIFO
   tx_free: indicates that the tx FIFO is not full
   busy: indicates whether the controller is busy or idle


Transactions:
------------
  The type of transaction depends on its length (DTR_LENGTH).
  When DTR_LENGTH is less than or equal to  DATA_W * FIFO_DEPTH, the
transaction starts puting data to send on the tx FIFO and then wait for its
ending to read the data received (see RX FIFO Reading below).
  When DTR_LENGTH is greater than DATA_W * FIFO_DEPTH, the data to send
should be placed by parts in the tx FIFO, waiting until the FIFOs would be
not full again to put the remaining data. In this way, the  slave remains
selected between transfer of successive parts. Also data arrived be read to
prevent rx FIFO overflow.
  Some examples are described below.


SPI Channel bit rate:
--------------------
  The frequency of transmission in the SPI bus is half of the ena_i input
signal's frequency, so it's recommended that this signal was a division
of the system clock signal. If the ena_i signal stops, will also stop
tx/rx controller's machine.


Interruptions:
-------------
  The core has outputs for data ready and overflow interruption requests.

- Data Ready IRQ: the behaviour of this output depends on the DR_IRQ_ALW
generic. If true, the controller will set an interruption request for each
DATA_W bits transfered, even though the slave remains selected, it means,
even though the total transaction has not complete. If DR_IRQ_ALWS is false,
the controller will set a single interruption request at the ending of
the total transaction, it means when the slave will released.

- Overflow IRQ: through this output, the controller set interruption requests
when an overflow occurs in rx or tx FIFOs. After that, is recommended read
the status register where the error source is described.


RX FIFO Reading:
---------------
  It's important to note that, given the architecture of the FIFOs used, for
consecutive reading of more than one value from rx FIFO, delay cycle must
be added at beginning of reading. As example, see. /testbench/spi_tb.vhdl.


Instantiation example:
---------------------
(see "dut" component in ./testbench/spi_tb.vhdl)


Examples of transactions:
------------------------
  Here are two examples that shows the two basic modes for transactions using
the SPI_WB core.

- Transaction with DTR_LENGTH less than or equal to DATA_W*FIFO_DEPTH
  This is the simplest case. DR_IRQ_ALWS=false is used, so the core sets a data
ready IRQ only at the end of the operation.
  The cycle would be as follow:
1- Check the controller is not busy by reading the status register.
2- If there are more than one slave, the corresponding slave  must be set in
the control register.
3- Put data to send in tx FIFOs by succesive writings in tx_fifo_in register.
4- Wait for data ready IRQ and read data received, available in rx FIFO.

- Transaction con DTR_LENGTH=2, FIFO_DEPTH=1 and DR_IRQ_ALWS=true
  The transaction cycle would be as follow:
1- Check the controller is not busy by reading the status register.
2- If there are more than one slave, the corresponding slave  must be set in
the control register.
3- Put first DATA_W bits to send in tx_fifo_in register. Wait until
tx_fifo_in be released again and put the last DATA_w.
4- Wait for data ready IRQ and read data received, available in rx_fifo_out
register.
4- Wait for the next data ready IRQ and read the next data received, available
in rx_fifo_out register.


Area Measurements:
-----------------
  The file Makefile in ./FPGA/mide directory allows get several synthesis of
the SPI_WB core for a Xilinx xc3s400aft256-4 Spartan 3A FPGA, for diferent
generic's values. This allows to compare the area occupation and other
resources consumed for diferent core's configurations. The results appears in
mide.txt in the same directory.


Connections:
-----------
SPI_WB:
- Generics:
      --FIFO
      FIFO_ADDR_W   : natural:=3;
      FIFO_DEPTH    : natural:=6;
      --SPI
      SCLK_PHASE    : std_logic:='0';
      SCLK_POLARITY : std_logic:='0';
      SLAVE_QTT     : positive:=2;
      SS_BITS_QTT   : positive:=1;
      MSB_IS_FIRST  : boolean:=false;
      --FIFO, SPI and Wishbone
      DR_IRQ_ALWS   : boolean:=false;
      DATA_W        : positive:=8
- Ports:
      --Wishbone
      wb_clk_i      : in  std_logic;
      wb_rst_i      : in  std_logic;
      wb_adr_i      : in  std_logic_vector(0 downto 0);
      wb_dat_i      : in  std_logic_vector(DATA_W-1 downto 0);
      wb_dat_o      : out std_logic_vector(DATA_W-1 downto 0);
      wb_we_i       : in  std_logic;
      wb_stb_i      : in  std_logic;
      wb_ack_o      : out std_logic;
      --SPI
      ena_i         : in  std_logic;
      miso_i        : in  std_logic;
      sclk_o        : out std_logic;
      mosi_o        : out std_logic;
      ss_o          : out std_logic_vector(SLAVE_QTT-1 downto 0);
      --Outputs for interruption requests
      dr_irq_o      : out std_logic;
      oe_irq_o      : out std_logic   


