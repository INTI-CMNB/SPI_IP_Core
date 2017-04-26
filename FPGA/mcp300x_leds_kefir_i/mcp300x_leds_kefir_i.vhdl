------------------------------------------------------------------------------
----                                                                      ----
----  MCP3008 test for Kéfir I                                            ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  Continually starts A/D convertions. Displays the 4 MSBs in the LEDs ----
----                                                                      ----
----  To Do:                                                              ----
----  -                                                                   ----
----                                                                      ----
----  Author:                                                             ----
----    - Salvador E. Tropea, salvador en inti.gob.ar                     ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2016 Salvador E. Tropea <salvador en inti.gob.ar>      ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      MCP300x_LEDs_Kefir_I(TopLevel) (Entity and arch.)  ----
---- File name:        mcp300x_leds_kefir_i.vhdl                          ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
---- Target FPGA:      iCE40HX4K-TQ144                                    ----
---- Language:         VHDL                                               ----
---- Wishbone:         None                                               ----
---- Synthesis tools:  iCEcube2 2016.02                                   ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library SPI;
use SPI.Devices.all;

entity MCP300x_LEDs_Kefir_I is
   port(
      CLK     : in  std_logic;
      LED1    : out std_logic;
      LED2    : out std_logic;
      LED3    : out std_logic;
      LED4    : out std_logic;
      AD_CS   : out std_logic;
      AD_Din  : out std_logic;
      AD_Dout : in  std_logic;
      AD_Clk  : out std_logic;
      SS_B    : out std_logic);
end entity MCP300x_LEDs_Kefir_I;

architecture TopLevel of MCP300x_LEDs_Kefir_I is
   -- The oscilator is 24 MHz, with 12 we get 1 MHz SPI clock. 55,6 ks/s
   constant DIVIDER   : positive:=12;
   constant SHOW_MSBS : boolean:=false;
   signal cnt_div_spi : unsigned(3 downto 0):=(others => '0');
   signal spi_ena     : std_logic;
   signal eoc         : std_logic;
   signal cur_val     : std_logic_vector(9 downto 0);
   signal last_val_r  : std_logic_vector(9 downto 0):=(others => '0');
begin
   SS_B <= '1'; -- Disable the SPI memory

   ----------------------
   -- SPI clock enable --
   ----------------------
   do_spi_div:
   process (CLK)
   begin
      if rising_edge(CLK) then
         cnt_div_spi <= cnt_div_spi+1;
         if cnt_div_spi=DIVIDER-1 then
            cnt_div_spi <= (others => '0');
         end if;
      end if;
   end process do_spi_div;
   spi_ena <= '1' when cnt_div_spi=DIVIDER-1 else '0';

   -------------------
   -- A/D interface --
   -------------------
   the_AD : MCP300x
      port map(
         -- System
         clk_i => CLK, rst_i => '0',
         -- Master interface
         start_i => '1', busy_o => open, chn_i => "000", single_i => '1',
         ena_i => spi_ena, eoc_o => eoc, data_o => cur_val,
         -- A/D interface
         ad_ncs_o => AD_CS, ad_clk_o => AD_Clk, ad_din_o => AD_Din,
         ad_dout_i => AD_Dout);
   ad_val_reg:
   process (CLK)
   begin
      if rising_edge(CLK) then
         if eoc='1' then
            last_val_r <= cur_val;
         end if;
      end if;
   end process ad_val_reg;

   -----------------------------------
   -- Show some bits using the LEDs --
   -----------------------------------
   do_msbs:
   if SHOW_MSBS generate
      LED4 <= last_val_r(9);
      LED3 <= last_val_r(8);
      LED2 <= last_val_r(7);
      LED1 <= last_val_r(6);
   end generate do_msbs;

   do_lsbs:
   if not(SHOW_MSBS) generate
      LED4 <= last_val_r(3);
      LED3 <= last_val_r(2);
      LED2 <= last_val_r(1);
      LED1 <= last_val_r(0);
   end generate do_lsbs;
end architecture TopLevel; -- Entity: MCP300x_LEDs_Kefir_I

