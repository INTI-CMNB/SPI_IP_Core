------------------------------------------------------------------------------
----                                                                      ----
----  Testbench for SPI controller                                        ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  Testbench for SPI controller using an S25FL flash memory simulator  ----
----                                                                      ----
----  To Do:                                                              ----
----  -                                                                   ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon en inti gob ar                      ----
----    - Salvador E. Tropea, salvador en inti gob ar                     ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2010 Francisco Salomón <fsalomon en inti gob ar>       ----
---- Copyright (c) 2008 Salvador E. Tropea <salvador en inti gob ar>      ----
---- Copyright (c) 2008-2010 Instituto Nacional de Tecnología Industrial  ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      SPI_Controller_TB(Bench)                           ----
---- File name:        spi_controller_tb.vhdl                             ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   SPI.Devices                                        ----
----                   SPI.Testbench                                      ----
----                   utils.StdIO                                        ----
----                   utils.Str                                          ----
----                   utils.Stdlib                                       ----
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
library utils;
use utils.StdIO.all;
use utils.Str.all;
use utils.Stdlib.all;


entity SPI_Controller_TB is
end entity SPI_Controller_TB;

architecture Bench of SPI_Controller_TB is
   constant FREQUENCY   : positive:=50e6;
   constant CLK_PER     : time:=(1.0/real(FREQUENCY))*1e6 us;
   constant ENA_DIV     : positive:=2;
   constant SPIBIT_TIME : time:=CLK_PER*(ENA_DIV*2);
   constant TOTAL_LOOPS : positive:=2;
   constant SQTT        : positive:=8; -- slave quantity
   constant SSBQTT      : positive:=3; -- ss bits quantity
   constant SSELECTED   : natural:=5;  -- slave selected

   signal clk         : std_logic;
   signal rst         : std_logic;
   signal stop_sim    : std_logic:='0';
   signal ena         : std_logic;
   signal start       : std_logic:='0';
   signal c_busy      : std_logic;
   signal c_irq       : std_logic;

   signal miso        : std_logic;
   signal mosi        : std_logic;
   signal sclk        : std_logic;
   signal ss          : std_logic_vector(SQTT-1 downto 0):=(others => '1');
   signal tx_r        : std_logic_vector(7 downto 0):=(others => '0');
   signal rx_r        : std_logic_vector(7 downto 0):=(others => '0');

begin
   -- clock and reset signals from utils library
   do_clk_and_rst: SimpleClock
      generic map(FREQUENCY => FREQUENCY)
      port map(
         clk_o => clk, nclk_o => open, rst_o => rst, stop_i => stop_sim);

   -- enable signal from utils library
   do_enable: SimpleDivider
      generic map(DIV => ENA_DIV)
      port map(
         clk_i => clk, rst_i => rst, div_o => ena);

   -- device under test
   dut : SPI_controller
      generic map(
         SCLK_PHASE    => '0',    SCLK_POLARITY => '0',
         SLAVE_QTT     => SQTT,   SS_BITS_QTT   => SSBQTT,
         DATA_W        => 8,      MSB_IS_FIRST  => true
         )
      port map(
         -- system
         clk_i   => clk,   rst_i => rst,     ena_i => ena,
         -- interface
         start_i => start, tx_i  => tx_r,    rx_o  => rx_r,
         ss_i    => std_logic_vector(to_unsigned(SSELECTED,SSBQTT)),
         busy_o  => c_busy,irq_o   => c_irq,
         -- spi
         miso_i  => miso,  sclk_o  => sclk,  mosi_o  => mosi,
         ss_o    => ss
         );

   -- memory simulator
   mem_sim : S25FL_sim
      port map(
         sck_i => sclk, si_i => mosi, so_o => miso, cs_i => ss(SSELECTED));

   -- genarate operation
   gen_op:
   process
      variable byte_cnt : natural range 0 to 6:= 0;
      variable loop_cnt : natural range 1 to TOTAL_LOOPS:= 1;
   begin
      outwrite("* Testbench Start");
      wait until falling_edge(rst);
      loop
         byte_cnt:=0;
         tx_r <= RDID_CMD;
         assert c_busy='0' report "Incorrect initial level on busy signal"
            severity failure;
         outwrite("Request for transaction number " & integer'image(loop_cnt)
                  & " of " & integer'image(TOTAL_LOOPS));
         start <= '1';
         outwrite("Checking busy signal...");
         wait until rising_edge(clk) and (ena='1');
         wait for 1 fs;
         assert c_busy='1' report "Controller not started"
            severity failure;
         outwrite("Checking irq generation...");
         wait for (8*SPIBIT_TIME);
         wait until rising_edge(clk) and (ena='1');
         wait for 1 fs;
         assert c_irq='1' report "Irq for first packet not asserted"
            severity failure;
         byte_cnt:=byte_cnt+1;
         outwrite("Waiting end of operation...");
         loop
            wait for (8*SPIBIT_TIME);
            wait until rising_edge(clk) and (ena='1');
            wait for 1 fs;
            assert c_irq='1' report "Irq for packet "& integer'image(byte_cnt)
                  & "  not asserted" severity failure;
            assert rx_r= MAN_DEV_ID(byte_cnt-1) report "Wrong packet "
               & integer'image(byte_cnt) & " arrived ("&hstr(rx_r)&")"
               severity failure;
            if byte_cnt=4 then
               start <= '0';
               byte_cnt:=byte_cnt+1;
            elsif byte_cnt=5 then
               exit;
            else
               byte_cnt:=byte_cnt+1;
            end if;
         end loop;
         assert c_busy='0' report "Incorrect level on busy signal after irq"
            severity failure;
         -- next loop
         if loop_cnt=TOTAL_LOOPS then
            exit;
         else
            loop_cnt:=loop_cnt+1;
         end if;
      end loop;
      stop_sim <= '1';
      outwrite("* Testbench OK");
      wait;
   end process gen_op;

end architecture Bench; -- Entity: SPI_Controller_TB

