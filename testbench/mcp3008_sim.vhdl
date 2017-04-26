------------------------------------------------------------------------------
----                                                                      ----
----  MCP3008 A/D simulator (SPI slave)                                   ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  This core simulates an MCP3008 A/D converter and is useful for      ----
----  testing the MCP300x core.@p                                         ----
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
---- Design unit:      MCP3008_Sim(Simulator) (Entity and architecture)   ----
---- File name:        mcp3008_sim.vhdl                                   ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   utils.StdIO                                        ----
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

entity MCP3008_Sim is
   port(
      -- SPI interface
      ncs_i  : in  std_logic;
      clk_i  : in  std_logic;
      din_i  : in  std_logic;
      dout_o : out std_logic;
      -- Debug control
      rst_i  : in  std_logic;
      data_i : in  std_logic_vector(9 downto 0));
end entity MCP3008_Sim;

architecture Simulator of MCP3008_Sim is
   type state_t is (idle, start, sng_diff, chn_d2, chn_d1, chn_d0, sample,
                    null_char, data_out, stop);
   signal state : state_t:=idle;
   signal chn : unsigned(2 downto 0);
begin
   do_ad:
   process (rst_i, ncs_i, clk_i)
      variable chn_aux : unsigned(2 downto 0);
      variable cnt : integer;
   begin
      if rst_i/='0' then
         state  <= idle;
         dout_o <= 'Z';
      elsif ncs_i='1' then
         if state=stop then
            outwrite("* End of conversion");
         elsif state/=idle then
            report "/CS deasserted before ending" severity note;
         end if;
         state  <= idle;
         dout_o <= 'Z';
      else
         if state=idle then
            state <= start;
            assert clk_i='0' report "/CS falls and CLK isn't 0" severity failure;
         elsif rising_edge(clk_i) then
            case state is
                 when start =>
                      assert din_i='1' report "/CS falls and not START bit" severity failure;
                      state <= sng_diff;
                      outwrite("* Start of conversion");
                 when sng_diff =>
                      if din_i='1' then
                         outwrite("- Single end");
                      else
                         outwrite("- Differential");
                      end if;
                      state <= chn_d2;
                 when chn_d2 =>
                      chn(2) <= din_i;
                      state <= chn_d1;
                 when chn_d1 =>
                      chn(1) <= din_i;
                      state <= chn_d0;
                 when chn_d0 =>
                      chn(0) <= din_i;
                      chn_aux:=chn(2 downto 1)&din_i;
                      outwrite("- Channel: "&integer'image(to_integer(chn_aux)));
                      state <= sample;
                 when sample =>
                      state <= null_char;
                 when others =>
                      null;
            end case;
         elsif falling_edge(clk_i) then
               case state is
                    when null_char =>
                         dout_o <= '0';
                         state  <= data_out;
                         cnt:=9;
                    when data_out =>
                         dout_o <= data_i(cnt);
                         if cnt=0 then
                            state <= stop;
                         else
                            cnt:=cnt-1;
                         end if;
                    when stop =>
                         report "End of cycle with CS asserted" severity failure;
                    when others =>
                         null;
               end case;
         end if;
      end if;
   end process do_ad;
end architecture Simulator; -- Entity: MCP3008_Sim

