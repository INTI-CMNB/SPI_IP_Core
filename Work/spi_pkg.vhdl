------------------------------------------------------------------------------
----                                                                      ----
----  SPI package                                                         ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----    Package file for spi                                              ----
----                                                                      ----
----  To Do:                                                              ----
----  -                                                                   ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon@inti.gob.ar                         ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2010 Francisco Salomón <fsalomon@inti.gob.ar>          ----
---- Copyright (c) 2010 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      Devices (Package)                                  ----
---- File name:        spi_pkg.vhdl                                       ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
---- Target FPGA:      Spartan 3A (XC3S400-FT256)                         ----
---- Language:         VHDL                                               ----
---- Wishbone:         SLAVE (rev B.3)                                    ----
---- Synthesis tools:  Xilinx Release 10.1i - xst K.37                    ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package Devices is
   -- SPI Controller
   component SPI_controller is
      generic(
         SCLK_PHASE    : std_logic:='0'; -- Indicates Sclk's edge for sampling
         SCLK_POLARITY : std_logic:='0'; -- Sclk level for no transaction state
         SLAVE_QTT     : positive:=2;    -- Number of selectable slave devices
         SS_BITS_QTT   : positive:=1;    -- Number of bits for ss input
         DATA_W        : positive:=8;    -- Transaction data width
         MSB_IS_FIRST  : boolean :=false -- MSB is sent first
             );
      port(
         -- System
         clk_i         : in  std_logic;
         rst_i         : in  std_logic;
         ena_i         : in  std_logic;
         -- Interface
         start_i       : in  std_logic;
         tx_i          : in  std_logic_vector(DATA_W-1 downto 0);
         rx_o          : out std_logic_vector(DATA_W-1 downto 0);
         ss_i          : in  std_logic_vector(SS_BITS_QTT-1 downto 0);
         busy_o        : out std_logic;
         irq_o         : out std_logic;
         -- SPI
         miso_i        : in  std_logic;
         sclk_o        : out std_logic;
         mosi_o        : out std_logic;
         ss_o          : out std_logic_vector(SLAVE_QTT-1 downto 0):=
                         (others => '1')
           );
   end component SPI_controller;

   -- SPI Master Controller
   component SPI_Master is
      generic(
         DATA_W        : positive:=8     -- Transaction data width
             );
      port(
         -- System
         clk_i         : in  std_logic;
         rst_i         : in  std_logic;
         ena_i         : in  std_logic; -- 2*SCK
         -- Interface
         start_i       : in  std_logic;
         tx_i          : in  std_logic_vector(DATA_W-1 downto 0);
         rx_o          : out std_logic_vector(DATA_W-1 downto 0);
         busy_o        : out std_logic;
         irq_o         : out std_logic;
         ack_i         : in  std_logic; -- IRQ Ack
         -- Mode options
         cpol_i        : in  std_logic; -- SCK value for idle
         dord_i        : in  std_logic; -- 1 LSB first
         cpha_i        : in  std_logic; -- 1 Trailing sample
         -- SPI
         sclk_o        : out std_logic;
         miso_i        : in  std_logic;
         mosi_en_o     : out std_logic;
         mosi_o        : out std_logic);
   end component SPI_Master;

   -- SPI Wishbone
   component SPI_WB is
      generic(
         -- FIFO
         FIFO_ADDR_W   : natural:=3;     -- Address width
         FIFO_DEPTH    : natural:=6;     -- Size(less or equal to 2^FIFO_ADDR_W)
         -- SPI Generics
         SCLK_PHASE    : std_logic:='0'; -- SClk phase
         SCLK_POLARITY : std_logic:='0'; -- SClk polarity
         SLAVE_QTT     : positive:=2;    -- Number of selectable slave devices
         SS_BITS_QTT   : positive:=1;    -- Number of bits for slave select
         MSB_IS_FIRST  : boolean:=false; -- MSB is sent first
         -- SPI and WISHBONE
         DR_IRQ_ALWS   : boolean:=false; -- Irqs after each data ready event
         DATA_W        : positive:=8     -- Bus, fifo and transaction width
         );
      port(
         -- WISHBONE
         wb_clk_i      : in  std_logic;
         wb_rst_i      : in  std_logic;
         wb_adr_i      : in  std_logic_vector(0 downto 0);
         wb_dat_i      : in  std_logic_vector(DATA_W-1 downto 0);
         wb_dat_o      : out std_logic_vector(DATA_W-1 downto 0);
         wb_we_i       : in  std_logic;
         wb_stb_i      : in  std_logic;
         wb_ack_o      : out std_logic;
         -- Controller
         ena_i         : in  std_logic;
         miso_i        : in  std_logic;
         sclk_o        : out std_logic;
         mosi_o        : out std_logic;
         ss_o          : out std_logic_vector(SLAVE_QTT-1 downto 0);
         -- Data ready and overflow error interruptions request
         dr_irq_o      : out std_logic;
         oe_irq_o      : out std_logic
         );
   end component SPI_WB;

   -- MCP300x
   component MCP300x is
      generic(
         FULL_RESET : boolean:=true); -- Reset affects all regs, even when not needed
      port(
         -- System
         clk_i    : in  std_logic; -- System clock
         rst_i    : in  std_logic; -- System reset
         -- Master interface
         start_i  : in  std_logic; -- Start conversion
         busy_o   : out std_logic; -- Converting
         chn_i    : in  std_logic_vector(2 downto 0); -- A/D channel
         single_i : in  std_logic; -- Single end (0 == diff.)
         ena_i    : in  std_logic; -- 2*SPI clk
         eoc_o    : out std_logic; -- End of conversion
         data_o   : out std_logic_vector(9 downto 0); -- Last A/D value
         -- A/D interface
         ad_ncs_o : out std_logic;   -- SPI /CS
         ad_clk_o : out std_logic;   -- SPI clock
         ad_din_o : out std_logic;   -- SPI A/D Din (MOSI)
         ad_dout_i: in  std_logic);  -- SPI A/D Dout (MISO)
   end component MCP300x;
end package Devices;

