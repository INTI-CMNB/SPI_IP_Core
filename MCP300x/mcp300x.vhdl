------------------------------------------------------------------------------
----                                                                      ----
----  MCP300x A/D controller (SPI master)                                 ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  This core implements the communication with the MCP3004/8 A/D       ----
----  converter. This is basically a simple SPI.@p                        ----
----  A new conversion is started when start_i is asserted, it must be    ----
----  kept high until busy_o becomes active.@p                            ----
----  chn_i and single_i selects the channel and mode (see datasheet).@p  ----
----  The eoc_o signal indicates that a new value is available at data_o. ----
----  This value must be read before a new conversion is started. The     ----
----  eoc_o signal lasts 1 clock.@p                                       ----
----  The SPI clock is determined by ena_i. This signal is enabled only   ----
----  during one clk_i cycle and it's frequency should be twice the       ----
----  desired SPI clock.@p                                                ----
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
---- Design unit:      MCP300x(RTL) (Entity and architecture)             ----
---- File name:        mcp300x.vhdl                                       ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
---- Target FPGA:      None                                               ----
---- Language:         VHDL                                               ----
---- Wishbone:         None                                               ----
---- Synthesis tools:  None                                               ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MCP300x is
   generic(
      FULL_RESET : std_logic:='1'); -- Reset affects all regs, even when not needed
                                    -- Using std_logic for Verilog compat
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
end entity MCP300x;

architecture RTL of MCP300x is
   type state_t is (idle, tx, sample, rx, eoc);
   signal state    : state_t:=idle;
   signal data_r   : std_logic_vector(9 downto 0):=(others => '0');
   signal data_tx  : std_logic_vector(4 downto 0);
   signal cnt      : unsigned(3 downto 0):=(others => '0');
   signal ad_clk_r : std_logic:='0';
begin
   -- 1  START
   -- Sn Single/not(Differential)
   -- D2 Channel bit 2
   -- D1 Channel bit 1
   -- D0 Channel bit 0
   data_tx <= '1'&single_i&chn_i;
   do_FSM:
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i='1' then
            state  <= idle;
            if FULL_RESET='1' then
               data_r   <= (others => '0');
               cnt      <= (others => '0');
               ad_clk_r <= '0';
            end if;
         else
            -- Generate the SPI clock all the time
            if ena_i='1' then
               ad_clk_r <= not(ad_clk_r);
            end if;
            case state is
                 when idle =>
                      if start_i='1' and ena_i='1' then
                         state    <= tx;
                         cnt      <= to_unsigned(4,cnt'length);
                         ad_clk_r <= '0';
                      end if;
                 when tx =>
                      if ena_i='1' and ad_clk_r='1' then
                         cnt <= cnt-1;
                         if cnt=0 then
                            state <= sample;
                         end if;
                      end if;
                 when sample =>
                      if ena_i='1' and ad_clk_r='1' then
                         state <= rx;
                         cnt   <= to_unsigned(11,cnt'length);
                      end if;
                 when rx =>
                      if ena_i='1' then
                         if ad_clk_r='0' then
                            data_r <= data_r(8 downto 0)&ad_dout_i;
                            cnt    <= cnt-1;
                         elsif cnt=0 then
                            state <= eoc;
                         end if;
                      end if;
                 when others => -- eoc
                      if ena_i='1' and ad_clk_r='1' then
                         if start_i='1' then
                            state <= tx;
                            cnt   <= to_unsigned(4,cnt'length);
                         else
                            state <= idle;
                         end if;
                      end if;
            end case;
         end if;
      end if;
   end process do_FSM;
   -- Master interface
   busy_o <= '1' when state/=idle and state/=eoc else '0'; -- Converting
   eoc_o  <= '1' when state=eoc and ena_i='1' else '0'; -- End of conversion
   data_o <= data_r; -- Last A/D value
   -- A/D interface
   ad_ncs_o <= '1' when state=idle or state=eoc else '0';   -- SPI /CS
   ad_clk_o <= ad_clk_r;   -- SPI clock
   ad_din_o <= data_tx(to_integer(cnt)) when state=tx else '0';   -- SPI A/D Din (MOSI)
end architecture RTL; -- Entity: MCP300x

