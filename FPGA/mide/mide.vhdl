------------------------------------------------------------------------------
----                                                                      ----
----  Area measurement for the SPI core                                   ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----   Code for SPI_WB core area measurement, using an Spartan 3A         ----
----  (XC3S400-FT256)                                                     ----
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
---- Design unit:      Test(Xilinx)                                       ----
---- File name:        mide.vhdl                                          ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   SPI.Devices                                        ----
---- Target FPGA:      Spartan 3A (XC3S400-FT256)                         ----
---- Language:         VHDL                                               ----
---- Wishbone:         None                                               ----
---- Synthesis tools:  Xilinx Release 10.1i - xst K.37                    ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library SPI;
use SPI.Devices.all;

entity Test is
   generic(
      ONLY_CTR      : boolean:=false; -- Only controller or spi_wb
      -- FIFO
      FIFO_ADDR_W   : natural:=1;     -- Address width
      FIFO_DEPTH    : natural:=1;     -- Size(less or equal to 2^FIFO_ADDR_W)
      -- SPI Generics
      SCLK_PHASE    : std_logic:='0'; -- SClk phase
      SCLK_POLARITY : std_logic:='0'; -- SClk polarity
      SLAVE_QTT     : positive:=2;    -- Number of selectable slave devices
      SS_BITS_QTT   : positive:=1;    -- Number of bits for slave select
      MSB_IS_FIRST  : boolean:=false; -- MSB is sent first
      -- FIFO, SPI and Wishbone
      DATA_W        : positive:=8     -- Bus, fifo and transaction width
      );
   port(
      -- Wishbone
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
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
      -- Interruptions Request
      dr_irq_o      : out std_logic;    -- data ready irq
      oe_irq_o      : out std_logic;    -- error irq
      -- Only Controller
      salreg_o      : out std_logic;
      start_i       : in  std_logic;
      ss_i          : in  std_logic_vector(SS_BITS_QTT-1 downto 0);
      busy_o        : out std_logic;
      irq_o         : out std_logic
      );
end entity Test;

architecture Xilinx of Test is
begin

   -- Only for spi controller
   only_controller:
   if ONLY_CTR generate
      dut : SPI_controller
          generic map(
             SCLK_PHASE  => SCLK_PHASE,  SCLK_POLARITY => SCLK_POLARITY,
             SLAVE_QTT   => SLAVE_QTT,   SS_BITS_QTT   => SS_BITS_QTT,
             DATA_W      => DATA_W,      MSB_IS_FIRST  => MSB_IS_FIRST
             )
          port map(
             clk_i   => clk_i,   rst_i  => rst_i,    ena_i => ena_i,
             start_i => start_i, tx_i   => wb_dat_i, rx_o  => wb_dat_o,
             ss_i    => ss_i,    busy_o => busy_o,   irq_o => dr_irq_o,
             miso_i  => miso_i,  sclk_o => sclk_o,   mosi_o => mosi_o,
             ss_o    => ss_o
             );
   end generate only_controller;

   -- SPI with Wishbone interface
   spi_wishbone:
   if not(ONLY_CTR) generate
      dut : SPI_WB
          generic map(
             FIFO_ADDR_W   => FIFO_ADDR_W,  FIFO_DEPTH    => FIFO_DEPTH,
             SCLK_PHASE    => SCLK_PHASE,   SCLK_POLARITY => SCLK_POLARITY,
             SLAVE_QTT     => SLAVE_QTT,    SS_BITS_QTT   => SS_BITS_QTT,
             MSB_IS_FIRST  => MSB_IS_FIRST, DATA_W        => DATA_W
             )
          port map(
             -- Wishbone
             wb_clk_i => clk_i,     wb_rst_i => rst_i,     wb_adr_i => wb_adr_i,
             wb_dat_i => wb_dat_i,  wb_dat_o => wb_dat_o,  wb_we_i  => wb_we_i,
             wb_stb_i => wb_stb_i,  wb_ack_o => wb_ack_o,
             -- Controller
             ena_i    => ena_i,     miso_i   => miso_i,    sclk_o   => sclk_o,
             mosi_o   => mosi_o,    ss_o     => ss_o,
             -- Interruptions Request
             dr_irq_o => dr_irq_o,  oe_irq_o => oe_irq_o
             );
   end generate spi_wishbone;

end architecture Xilinx; -- Entity: Test
