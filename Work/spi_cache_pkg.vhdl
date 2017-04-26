------------------------------------------------------------------------------
----                                                                      ----
----  SPI Cache package                                                   ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----    Package file for spi cache                                        ----
----                                                                      ----
----  To Do:                                                              ----
----    -                                                                 ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon en inti gob ar                      ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2011 Francisco Salomón <fsalomon en inti gob ar>       ----
---- Copyright (c) 2011 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      CacheDevices (Package)                             ----
---- File name:        spi_cache_pkg.vhdl                                 ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
---- Target FPGA:                                                         ----
---- Language:         VHDL                                               ----
---- Wishbone:                                                            ----
---- Synthesis tools:  Xilinx Release 10.1i - xst K.37                    ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package CacheDevices is

   -- Commandss for Flash Memory with SPI interface
   constant READ_CMD     : std_logic_vector(7 downto 0):=x"03";-- Read command
   constant FREAD_CMD    : std_logic_vector(7 downto 0):=x"0B";-- Fast Read command

   -- SPI Cache
   component SPI_Cache is
      generic(
         -- Cache generics
         CACHE_LINE_L  : positive:=32;    -- Cache data width
         LINES_QTT     : positive:=1;     -- Number of lines
         ADDR_W        : positive:=32;    -- Address bus width
         DATA_W        : positive:=32;    -- Cache data width
         -- Others generics
         BYTE_ADDR     : boolean :=false; -- Byte-oriented address bus
         -- SPI generics
         SCLK_PHASE    : std_logic:='0';  -- Indicates Sclk's edge for sampling
         SCLK_POLARITY : std_logic:='0';  -- Sclk level for no transaction state
         MSB_IS_FIRST  : boolean :=true   -- MSB is sent first
             );
      port(
         -- Clock and reset
         clk_i         : in  std_logic;
         rst_i         : in  std_logic;
         -- Cache I/O
         adr_i         : in  std_logic_vector(ADDR_W-1 downto 0);
         dat_o         : out std_logic_vector(DATA_W-1 downto 0);
         read_i        : in  std_logic;
         wait_o        : out std_logic;
         -- Debug info
         state_o       : out std_logic_vector(2 downto 0);
         hit_o         : out std_logic;
         comp_o        : out std_logic_vector(LINES_QTT-1 downto 0);
         -- SPI I/O
         ena_i         : in  std_logic;
         miso_i        : in  std_logic;
         sclk_o        : out std_logic;
         mosi_o        : out std_logic;
         ss_o          : out std_logic
           );
   end component SPI_Cache;
end package CacheDevices;

