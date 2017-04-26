------------------------------------------------------------------------------
----                                                                      ----
----  SPI Controller                                                      ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  Configurable Master Serial Protocol Interface controller.           ----
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
---- Design unit:      SPI_controller(RTL) (Entity and architecture)      ----
---- File name:        spi_controller.vhdl                                ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   utils.Stdlib                                       ----
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
use IEEE.numeric_std.all;
library utils;
use utils.Stdlib.all;

entity SPI_controller is
   generic(
      SCLK_PHASE    : std_logic:='0'; -- Indicates Sclk's edge for sampling
      SCLK_POLARITY : std_logic:='0'; -- Sclk level for no transaction state
      SLAVE_QTT     : positive:=2;    -- Number of selectable slave devices
      SS_BITS_QTT   : positive:=1;    -- Number of bits for ss input
      DATA_W        : positive:=8;    -- Transaction data width
      MSB_IS_FIRST  : boolean :=false -- MSB is sent first
          );
   port(
      -- System
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      ena_i         : in  std_logic;
      -- Interface
      start_i       : in  std_logic;
      tx_i          : in  std_logic_vector(DATA_W-1 downto 0);
      rx_o          : out std_logic_vector(DATA_W-1 downto 0);
      ss_i          : in  std_logic_vector(SS_BITS_QTT-1 downto 0);
      busy_o        : out std_logic;
      irq_o         : out std_logic;
      -- SPI
      miso_i        : in  std_logic;
      sclk_o        : out std_logic;
      mosi_o        : out std_logic;
      ss_o          : out std_logic_vector(SLAVE_QTT-1 downto 0):=
                      (others => '1')
        );
end entity SPI_controller;

architecture RTL of SPI_controller is
   constant SCLK_IDLE_LV  : std_logic:=SCLK_POLARITY;
   type   state_type is (idle, init_sd, leading_sclk, trailing_sclk);
   signal state      : state_type:=idle; -- states for shifter_FSM.
   signal tx_shift_r : std_logic_vector(DATA_W-1 downto 0):=
                       (others=>'0');
   signal rx_shift_r : std_logic_vector(DATA_W-1 downto 0);
   signal ss         : std_logic_vector(SLAVE_QTT-1 downto 0):=
                       (others => '1');
   signal sclk_r     : std_logic:=SCLK_IDLE_LV;
begin
   shifter_FSM:
   process (clk_i)
      variable bit_cnt : natural range 0 to DATA_W:=0;
   begin
      if rising_edge(clk_i) then
         irq_o <= '0';
         if rst_i='1' then
            state <= idle;
            sclk_r <= SCLK_IDLE_LV;
            ss_o <= (others => '1');
            busy_o <= '0';
            bit_cnt:=0;
         elsif ena_i = '1' then
            case state is
                 when idle =>
                      if start_i='1' then -- init transaction
                         state <= init_sd;
                         bit_cnt:=0;
                         ss_o <= ss;  -- latch slave-select
                         if MSB_IS_FIRST then -- latch data to send
                            for i in tx_i'range loop
                               tx_shift_r((DATA_W-1)-i) <= tx_i(i);
                            end loop;
                         else
                            tx_shift_r <= tx_i;
                         end if;
                         busy_o <= '1';
                      end if;
                 when init_sd =>
                      state <= leading_sclk;
                      sclk_r <= not sclk_r;
                      if SCLK_PHASE='0' then
                         rx_shift_r <= rx_shift_r((DATA_W-2) downto 0)
                                       & miso_i;
                      end if;
                 when leading_sclk =>
                      state <= trailing_sclk;
                      sclk_r <= not sclk_r;
                      if SCLK_PHASE='0' then
                         tx_shift_r <= "0"&tx_shift_r(DATA_W-1 downto 1);
                      else
                         rx_shift_r <= rx_shift_r((DATA_W-2) downto 0)
                                       & miso_i;
                      end if;
                 when trailing_sclk =>
                      if bit_cnt=(DATA_W-1) then
                         if MSB_IS_FIRST then -- pass received data
                            rx_o <= rx_shift_r;
                         else
                            for i in rx_o'range loop
                                rx_o((DATA_W-1)-i) <= rx_shift_r(i);
                            end loop;
                         end if;
                         if start_i='1' then -- evaluate ongoing transaction
                            state <= init_sd;
                            bit_cnt:=0;
                            -- latch data to send, using the last slave
                            if MSB_IS_FIRST then
                               for i in tx_i'range loop
                                  tx_shift_r((DATA_W-1)-i) <= tx_i(i);
                               end loop;
                            else
                               tx_shift_r <= tx_i;
                            end if;
                         else -- end of transaction
                            state <= idle;
                            ss_o <= (others => '1');
                            busy_o <= '0';
                         end if;
                         irq_o <= '1';
                      else
                         bit_cnt:=bit_cnt+1;
                         state <= leading_sclk;
                         sclk_r  <= not sclk_r;
                         if SCLK_PHASE='0' then
                            rx_shift_r <= rx_shift_r((DATA_W-2) downto 0)
                                          & miso_i;
                         else
                            tx_shift_r <= "0" &
                                          tx_shift_r(DATA_W-1 downto 1);
                         end if;
                      end if;
            end case;
         end if;
      end if;
   end process shifter_FSM;

   -- Decode ss_i
   decode_ss_gen:
   for i in ss'range generate
       ss(i) <= '0' when i=sv2uint(ss_i) else '1';
   end generate decode_ss_gen;

   -- sclk output
   sclk_o <= sclk_r;

   -- mosi output
   mosi_o <= tx_shift_r(0);

end architecture RTL; -- Entity: SPI_controller
