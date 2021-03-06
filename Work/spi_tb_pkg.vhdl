------------------------------------------------------------------------------
----                                                                      ----
----  SPI testbench package                                               ----
----                                                                      ----
----  Internal file, can't be downloaded.                                 ----
----                                                                      ----
----  Description:                                                        ----
----    Package file for spi testbench                                    ----
----                                                                      ----
----  To Do:                                                              ----
----  -                                                                   ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salom�n, fsalomon@inti.gob.ar                         ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2010 Francisco Salom�n <fsalomon@inti.gob.ar>          ----
---- Copyright (c) 2010 Instituto Nacional de Tecnolog�a Industrial       ----
----                                                                      ----
---- For internal use, all rights reserved.                               ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      Testbench(Package)                                 ----
---- File name:        spi_tb_pkg.vhdl                                    ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
---- Target FPGA:                                                         ----
---- Language:         VHDL                                               ----
---- Wishbone:                                                            ----
---- Synthesis tools:                                                     ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package Testbench is

   -- Constants for S25 Memory
   -- Features
   constant CMD_LENGTH     : positive:=8;  -- Command length
   constant MDID_LENGTH    : positive:=40; -- Manufacturer and dev id length
   constant ADDRESS_LENGTH : positive:=24; -- Address length
   --Times
   constant TCSS        : time:=3 ns;        -- CS# setup time
   constant SCK_T_MIN   : time:=25 ns;       -- Minor period  for sck in
                                             -- normal op
   constant TWH         : time:=SCK_T_MIN/2; -- Minor Sck high time
   constant TWL         : time:=SCK_T_MIN/2; -- Minor Sck low time
   constant TV          : time:=2 ns;        -- Output valid time
   constant TDIH        : time:=2 ns;        -- Data input hold time
   constant TDIS        : time:=3 ns;        -- Data input setup time
   -- Commands
   constant READ_CMD    : std_logic_vector(7 downto 0):=x"03";-- Read command
   constant RDID_CMD    : std_logic_vector(7 downto 0):=x"9F";-- Rdid command
   constant RDSR_CMD    : std_logic_vector(7 downto 0):=x"05";-- Read status
   constant FREAD_CMD   : std_logic_vector(7 downto 0):=x"0B";-- Fast Read

   -- Manufacturer ID
   type mandevid_type is array(0 to 4) of
        std_logic_vector(7 downto 0);
   constant MAN_DEV_ID : mandevid_type:=
            (4 => x"01", 3 => x"03", 2 => x"18", 1 => x"20", 0 => x"01");

   -- Constants for SPI WISHBONE testbench
   -- WISHBONE bus data and controller transaction size = 8
   -- address
   constant TX_BUFFER : std_logic_vector(7 downto 0):=x"00";
   constant RX_BUFFER : std_logic_vector(7 downto 0):=x"00";
   constant CONTROL   : std_logic_vector(7 downto 0):=x"01";
   constant STATUS    : std_logic_vector(7 downto 0):=x"01";
   -- status register bits
   constant TX_FREE_BIT    : natural:=1;
   -- mask for status register bits
   constant BUSY       : std_logic_vector(7 downto 0):=x"01";
   constant TX_FREE    : std_logic_vector(7 downto 0):=x"02";
   constant DATA_READY : std_logic_vector(7 downto 0):=x"04";
   constant OERX       : std_logic_vector(7 downto 0):=x"08";
   constant OETX       : std_logic_vector(7 downto 0):=x"10";
   
   -- S25FL Simulator
   component S25FL_sim is
      generic(
        MEM_SIZE    : natural:=16777216; -- Memory size, in bytes
        DATA_FILE   : string:="testbench/data_file.dat" -- Memory content
             );
      port(
         sck_i      : in  std_logic;
         so_o       : out std_logic;
         si_i       : in  std_logic;
         cs_i       : in  std_logic:='1'
           );
   end component S25FL_sim;

end package Testbench;