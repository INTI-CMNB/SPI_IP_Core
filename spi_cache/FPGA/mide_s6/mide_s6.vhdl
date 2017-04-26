------------------------------------------------------------------------------
----                                                                      ----
----  Area measurement for the Cache SPI                                  ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----   Code for SPI Cache core area measurement, using an Spartan 3A      ----
----  (XC3S400-FT256)                                                     ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon en inti gob ar                      ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2011 Francisco Salomón <fsalomon en inti gob ar>       ----
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
----                   SPI.Cache                                        ----
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
use SPI.CacheDevices.all;

entity Test is
   generic(
      CACHE_LINE_L  : positive:=32;
      ADDR_W        : positive:=16;
      DATA_W        : positive:=16;
      BYTE_ADDR     : boolean :=false;
      LINES_QTT     : positive:=4;
      SCLK_PHASE    : std_logic:='0';
      SCLK_POLARITY : std_logic:='0';
      MSB_IS_FIRST  : boolean :=false
          );
   port(
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      adr_i         : in  std_logic_vector(ADDR_W-1 downto 0);
      dat_o         : out std_logic_vector(DATA_W-1 downto 0);
      read_i        : in  std_logic;
      wait_o        : out std_logic;
      ena_i         : in  std_logic;
      miso_i        : in  std_logic;
      sclk_o        : out std_logic;
      mosi_o        : out std_logic;
      ss_o          : out std_logic
        );
end entity Test;

architecture Xilinx of Test is
begin

   -- spi cache for flash memory
   cache : SPI_CACHE
      generic map(
         CACHE_LINE_L => CACHE_LINE_L, ADDR_W       => ADDR_W,
         DATA_W       => DATA_W,       BYTE_ADDR    => BYTE_ADDR,
         LINES_QTT   => LINES_QTT,     MSB_IS_FIRST => MSB_IS_FIRST)
      port map(
         -- Clock and reset
         clk_i  => clk_i, rst_i  => rst_i,
         -- Cache side I/O
         adr_i  => adr_i, dat_o  => dat_o, read_i => read_i,
         wait_o => wait_o,
         -- SPI side I/O
         ena_i    => ena_i,  miso_i => miso_i, sclk_o => sclk_o,
         mosi_o   => mosi_o, ss_o   => ss_o);

end architecture Xilinx; -- Entity: Test
