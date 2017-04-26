------------------------------------------------------------------------------
----                                                                      ----
----  SPI Master                                                          ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  Configurable Master Serial Protocol Interface controller.           ----
----  This is different than SPI_controller:                              ----
----  - Modes can be configured with signals, not just generics.          ----
----  - The SS logic is left to the upper level.                          ----
----  - We always return to IDLE before transmitting again.               ----
----  - IMPORTANT! assumes that start_i resets the ena_i generator. In    ----
----    this way start_i can last 1 clock cycle (no need to wait for      ----
----    busy_o to become 1).                                              ----
----                                                                      ----
----  To Do:                                                              ----
----  -                                                                   ----
----                                                                      ----
----  Author:                                                             ----
----    - Salvador E. Tropea, salvador en inti gob ar                     ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2017 Salvador E. Tropea <salvador en inti gob ar>      ----
---- Copyright (c) 2017 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      SPI_Master(RTL) (Entity and architecture)          ----
---- File name:        spi_master.vhdl                                    ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
---- Target FPGA:                                                         ----
---- Language:         VHDL                                               ----
---- Wishbone:         None                                               ----
---- Synthesis tools:                                                     ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SPI_Master is
   generic(
      DATA_W        : positive:=8     -- Transaction data width
          );
   port(
      -- System
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      ena_i         : in  std_logic; -- 2*SCK
      -- Interface
      start_i       : in  std_logic;
      tx_i          : in  std_logic_vector(DATA_W-1 downto 0);
      rx_o          : out std_logic_vector(DATA_W-1 downto 0);
      busy_o        : out std_logic;
      irq_o         : out std_logic;
      ack_i         : in  std_logic; -- IRQ Ack
      -- Mode options
      cpol_i        : in  std_logic; -- SCK value for idle
      dord_i        : in  std_logic; -- 1 LSB first
      cpha_i        : in  std_logic; -- 1 Trailing sample
      -- SPI
      sclk_o        : out std_logic;
      miso_i        : in  std_logic;
      mosi_en_o     : out std_logic;
      mosi_o        : out std_logic);
end entity SPI_Master;

architecture RTL of SPI_Master is
   signal reg_r      : std_logic_vector(DATA_W-1 downto 0):=(others=>'0');
   type   state_t is (idle, leading_sclk, trailing_sclk, stop);
   signal sclk_r     : std_logic:='0';
   signal bit_cnt    : natural range 0 to DATA_W-1:=0;
   signal state      : state_t:=idle; -- states for shifter_FSM.
   signal miso_r     : std_logic; -- Sampled MISO
begin
   shifter_FSM:
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i='1' then
            state  <= idle;
            sclk_r <= '0';
            irq_o  <= '0';
         else
            if ack_i='1' then
               irq_o  <= '0';
            end if;
            case state is
                 when idle =>
                      if start_i='1' then -- init transaction
                         state   <= leading_sclk;
                         reg_r   <= tx_i;
                         bit_cnt <= 0;
                      end if;
                 when leading_sclk =>
                      if ena_i='1' then
                         state  <= trailing_sclk;
                         sclk_r <= not sclk_r;
                         if cpha_i='0' then -- Leading sample
                            miso_r <= miso_i;
                         end if;
                      end if;
                 when trailing_sclk =>
                      if ena_i='1' then
                         sclk_r  <= not sclk_r;
                         if bit_cnt=DATA_W-1 then
                            state <= stop;
                            bit_cnt <= 0;
                         else
                            state <= leading_sclk;
                            bit_cnt <= bit_cnt+1;
                         end if;
                         if cpha_i/='0' then -- Leading sample
                            miso_r <= miso_i;
                         end if;
                      end if;
                 when others => -- stop
                      -- Maintain the last bit for half the clock to finish
                      -- If we don't do it we could violate the slave hold time
                      if ena_i='1' then
                         irq_o <= '1';
                         state <= idle;
                      end if;
            end case;
            -- Shift in cases
            if ena_i='1' then
               if (state=trailing_sclk and cpha_i='0') or
                  (((state=leading_sclk and bit_cnt/=0) or
                     state=stop) and cpha_i/='0') then
                  -- Shift
                  if dord_i='1' then
                     -- Right
                     reg_r <= miso_r&reg_r(DATA_W-1 downto 1);
                  else
                     -- Left
                     reg_r <= reg_r(DATA_W-2 downto 0)&miso_r;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process shifter_FSM;

   -- The FSM generates CPOL=0, if CPOL is 1 we just invert
   sclk_o <= sclk_r xor cpol_i;
   -- MOSI takes the LSB or MSB according to DORD
   mosi_o    <= reg_r(0) when dord_i='1' else reg_r(DATA_W-1);
   mosi_en_o <= '0' when state=idle else '1';
   rx_o      <= reg_r;
   busy_o    <= '0' when state=idle else '1';

end architecture RTL; -- Entity: SPI_Master

