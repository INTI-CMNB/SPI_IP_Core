------------------------------------------------------------------------------
----                                                                      ----
----  SPI Cache Testbench                                                 ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  Simple test for checking SPI Cache functionality.                   ----
----                                                                      ----
----  To Do:                                                              ----
----  Is not a good test yet... Is usefull if you read from position 0 of ----
----  a page.                                                             ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon at inti gob ar                      ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2011 Francisco Salomón <fsalomon at inti gob ar>       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      Entity(architecture) (Entity and architecture)     ----
---- File name:        spi_cache_tb.vhdl                                  ----
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

library SPI;
use SPI.Devices.all;
use SPI.Testbench.all;
use SPI.CacheDevices.all;
library utils;
use utils.StdIO.all;
use utils.Str.all;
use utils.Stdlib.all;

entity SPI_CACHE_TB is
end entity SPI_CACHE_TB;

architecture Bench of SPI_CACHE_TB is

   constant FREQUENCY   : positive:=50e6;-- frequency in Hz
   constant ENA_DIV     : positive:=4;   -- enable clk divisor for controller

   constant DATA_FILE   : string:="spi_cache.vhdl";
   constant MEM_SIZE    : natural:=10*1024; -- Memory size, in bytes
     
   constant CLK_PER     : time:=(1.0/real(FREQUENCY))*1e6 us;
   constant SPIBIT_TIME : time:=CLK_PER*(ENA_DIV*2);
   constant SQTT        : positive:=1; -- slave quantity
   constant SSBQTT      : positive:=1; -- ss bits quantity
   constant SSELECTED   : natural:=0;  -- slave selected
   constant ADDR_READ   : std_logic_vector(31 downto 0):=(others => '0');
   -- ADDR_READ_2 must be minor than ADDR_READ+32*4
   constant ADDR_READ_2 : std_logic_vector(31 downto 0):=x"00000008";
   constant ADDR_READ_3 : std_logic_vector(31 downto 0):=x"00000200";

   -- Clock, reset and enable signals
   signal clk : std_logic;
   signal rst : std_logic;
   signal ena : std_logic;

   -- type for SPI master out lines
   type spi_master_o_type is record
      sclk : std_logic;
      mosi : std_logic;
      --ss   : std_logic_vector(0 downto 0);
      ss   : std_logic;
   end record;

   -- stop simulation
   signal stop_sim   : std_logic:= '0';

   -- signals for data request to the cache
   signal adr      : std_logic_vector(31 downto 0):=(others => '0');
   signal m_data   : std_logic_vector(31 downto 0);
   signal read_req : std_logic;
   signal wait_req : std_logic;
   -- signals for SPI I/O
   signal spi_mo   : spi_master_o_type;
   signal miso     : std_logic;

   -- Get word from an slv8_array
   procedure get_word( f_array : in slv8_array;
                       address : in std_logic_vector;
                       outword : inout std_logic_vector) is
      variable int_addr, bytes, outlength : integer;
   begin
      outlength:=outword'length;
      bytes:=outlength/8;
      int_addr:=to_integer(unsigned(address));
      for i in 0 to (bytes-1) loop
           outword:=outword(outlength-8-1 downto 0) &
              f_array(int_addr+i);
      end loop;
   end procedure get_word;

begin

   -- clock and reset signals from utils library
   do_clk_and_rst: SimpleClock
      generic map(FREQUENCY => FREQUENCY)
      port map(
         clk_o  => clk, nclk_o => open, rst_o => rst,
         stop_i => stop_sim);

   -- enable signal from utils library
   do_enable: SimpleDivider
      generic map(DIV => ENA_DIV)
      port map(
         clk_i => clk, rst_i => rst, div_o => ena);

   -- device under test
   dut : SPI_CACHE
      generic map(
         CACHE_LINE_L => 32,  ADDR_W    => 32,
         DATA_W       => 32,
         LINES_QTT    => 4,   BYTE_ADDR => true )
      port map(
         -- Clock and reset
         clk_i  => clk, rst_i  => rst,
         -- Cache side I/O
         adr_i  => adr, dat_o  => m_data, read_i => read_req,
         wait_o => wait_req,
         -- SPI side I/O
         ena_i    => ena,         miso_i   => miso,
         sclk_o   => spi_mo.sclk, mosi_o   => spi_mo.mosi,
         ss_o     => spi_mo.ss);

   -- memory simulator
   mem_sim : S25FL_sim
      generic map(
         DATA_FILE => DATA_FILE, -- File with data to send
         MEM_SIZE  => MEM_SIZE)  -- Size of memory
      port map(
         sck_i => spi_mo.sclk,  si_i => spi_mo.mosi,
         so_o  => miso,         cs_i => spi_mo.ss);

   -- simulate transaction with spi chache
   sim_transaction:
   process
      variable word_cnt : integer:=0;
      variable w_temp   : std_logic_vector(31 downto 0);
      variable f_data   : slv8_array(0 to MEM_SIZE-1):=
        (others => (others => '1'));
   begin
      outwrite("* Init testbench ");
      readfc(DATA_FILE, f_data);
      wait until falling_edge(rst);

      outwrite("* Requesting data out of cache...");
      wait until rising_edge(clk);
      adr <= ADDR_READ;
      read_req <= '1';
      outwrite("Waiting reading init...");
      wait until rising_edge(clk);
      assert wait_req='1' report "Wait not set after not cached data request"
         severity failure;
      outwrite("Waiting end of reading...");
      wait until rising_edge(clk) and wait_req='0' for 10 ms;
      outwrite("Checking data...");
      loop
         get_word(f_data, adr, w_temp);
         wait for 1 fs;
         assert m_data=w_temp report "Wrong data for address x" & hstr(adr) &" [x"&
            hstr(m_data) & " when expected is x"& hstr(w_temp) & "]" severity failure;
         word_cnt:=word_cnt+1;
         if word_cnt=32 then
            read_req <= '0';
            exit;
         else
            adr <= std_logic_vector(to_unsigned(word_cnt*4, 32));
            wait until rising_edge(clk);
         end if;
      end loop;

      outwrite("* Requesting data in cache...");
      wait until rising_edge(clk);
      adr <= ADDR_READ_2;
      read_req <= '1';
      wait for 1 fs;
      assert wait_req='0' report "Wait set after cached data request"
         severity failure;
      wait until rising_edge(clk);
      outwrite("Checking data...");
      get_word(f_data, adr, w_temp);          
      wait for 1 fs;
      assert m_data=w_temp report "Wrong data for address x" & hstr(adr) &" [x"&
         hstr(m_data) & " when expected is x"& hstr(w_temp) & "]" severity failure;
      read_req <= '0';

      outwrite("* Requesting other data out of cache...");
      wait until rising_edge(clk);
      adr <= ADDR_READ_3;
      read_req <= '1';
      outwrite("Waiting reading init...");
      wait until rising_edge(clk);
      assert wait_req='1' report "Wait not set after not cached data request"
         severity failure;
      outwrite("Waiting end of reading...");
      wait until rising_edge(clk) and wait_req='0' for 10 ms;
      outwrite("Checking data...");
      get_word(f_data, adr, w_temp);
      wait for 1 fs;
      assert m_data=w_temp report "Wrong data for address x" & hstr(adr) &" [x"&
          hstr(m_data) & " when expected is x"& hstr(w_temp) & "]" severity failure;
      read_req <= '0';
      
      --Stopping test
      stop_sim <= '1';
      outwrite("* Testbench OK");
      wait;
   end process sim_transaction;
   
end architecture Bench; -- Entity: SPI_CACHE_TB
