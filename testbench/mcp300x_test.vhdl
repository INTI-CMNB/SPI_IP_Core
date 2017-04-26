------------------------------------------------------------------------------
----                                                                      ----
----  MCP300x core testbench                                              ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  Simple test for the MCP300x core. It connects the core to an        ----
----  MCP3008 simulator and tries 3 conversions.@p                        ----
----                                                                      ----
----  To Do:                                                              ----
----    -                                                                 ----
----                                                                      ----
----  Author:                                                             ----
----    - Salvador E. Tropea, salvador en inti.gob.ar                     ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2016 Salvador E. Tropea <salvador en inti.gob.ar>      ----
---- Copyright (c) 2016 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      MCP300x_Test(Simulator) (Entity and architecture)  ----
---- File name:        mcp300x_test.vhdl                                  ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   utils.StdIO                                        ----
----                   utils.Stdlib                                       ----
---- Target FPGA:      N/A                                                ----
---- Language:         VHDL                                               ----
---- Wishbone:         None                                               ----
---- Synthesis tools:  N/A                                                ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library utils;
use utils.StdIO.all;
use utils.Stdlib.all;

entity MCP300x_Test is
end entity MCP300x_Test;

architecture Simulator of MCP300x_Test is
   constant FREQUENCY   : positive:=24e6;
   constant ENA_DIV     : positive:=12;
   constant SPI_PERIOD  : time:=1 sec/(FREQUENCY/ENA_DIV/2);
   constant TEST1       : std_logic_vector(9 downto 0):="11"&x"5A";
   constant TEST2       : std_logic_vector(9 downto 0):="00"&x"A5";
   constant TEST3       : std_logic_vector(9 downto 0):="01"&x"F0";
   signal clk      : std_logic;
   signal rst      : std_logic;
   signal ena      : std_logic;
   signal stop_sim : std_logic:='0';
   signal ncs      : std_logic;
   signal spi_clk  : std_logic;
   signal mosi     : std_logic;
   signal miso     : std_logic;
   signal ad_val   : std_logic_vector(9 downto 0);
   signal rx_val   : std_logic_vector(9 downto 0);
   signal start    : std_logic;
   signal busy     : std_logic;
   signal chn      : std_logic_vector(2 downto 0);
   signal single   : std_logic;
   signal eoc      : std_logic;
begin
   do_clk_and_rst: SimpleClock
      generic map(FREQUENCY => FREQUENCY)
      port map(
         clk_o => clk, nclk_o => open, rst_o => rst, stop_i => stop_sim);

   do_enable: SimpleDivider
      generic map(DIV => ENA_DIV)
      port map(
         clk_i => clk, rst_i => rst, div_o => ena);

   AD_Sim : entity work.MCP3008_Sim
      port map(
         -- SPI interface
         ncs_i => ncs, clk_i => spi_clk, din_i => mosi, dout_o => miso,
         -- Debug control
         data_i => ad_val, rst_i => rst);

   DUT : entity work.MCP300x
      generic map(
         FULL_RESET => true) -- Reset affects all regs, even when not needed
      port map(
         -- System
         clk_i => clk, rst_i => rst,
         -- Master interface
         start_i => start, busy_o => busy, chn_i => chn, single_i => single,
         ena_i => ena, eoc_o => eoc, data_o => rx_val,
         -- A/D interface
         ad_ncs_o => ncs, ad_clk_o => spi_clk, ad_din_o => mosi,
         ad_dout_i => miso);

   do_test:
   process
   begin
      outwrite("* Testing the MCP300x controller");
      wait until falling_edge(rst);
      ad_val <= TEST1;
      chn    <= "011";
      single <= '1';
      start  <= '1';
      wait until busy='1' for 2*SPI_PERIOD;
      assert busy='1'
         report "Busy isn't asserted"
         severity failure;
      start <= '0';
      wait until eoc='1' for 20*SPI_PERIOD;
      assert eoc='1'
         report "EOC isn't asserted"
         severity failure;
      assert rx_val=TEST1
         report "Rx value doesn't match"
         severity failure;
      assert busy='0'
         report "Busy still asserted after conversion"
         severity failure;
      -- 2nd value
      ad_val <= TEST2;
      chn    <= "010";
      single <= '0';
      start  <= '1';
      wait until busy='1' for 2*SPI_PERIOD;
      assert busy='1'
         report "Busy isn't asserted"
         severity failure;
      start <= '0';
      wait until eoc='1' for 20*SPI_PERIOD;
      assert eoc='1'
         report "EOC isn't asserted"
         severity failure;
      assert rx_val=TEST2
         report "Rx value doesn't match"
         severity failure;
      assert busy='0'
         report "Busy still asserted after conversion"
         severity failure;
      -- 3rd value
      wait for 5*SPI_PERIOD;
      ad_val <= TEST3;
      chn    <= "110";
      single <= '0';
      start  <= '1';
      wait until busy='1' for 2*SPI_PERIOD;
      assert busy='1'
         report "Busy isn't asserted"
         severity failure;
      wait until eoc='1' for 20*SPI_PERIOD;
      assert eoc='1'
         report "EOC isn't asserted"
         severity failure;
      assert rx_val=TEST3
         report "Rx value doesn't match"
         severity failure;
      assert busy='0'
         report "Busy still asserted after conversion"
         severity failure;
      outwrite("* Successful test");
      stop_sim <= '1';
      wait;
   end process do_test;
end architecture Simulator; -- Entity: MCP300x_Test
