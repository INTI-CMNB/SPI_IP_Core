------------------------------------------------------------------------------
----                                                                      ----
----  SPI controller test on Avnet Spartan 3A Evaluation Kit              ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----  This test reads the ID of S25FL Flash SPI memory periodically       ----
----  (once a second) and checks the result. The status of the operation  ----
----  are reported through the LEDs in the board, using the following     ----
----  codes:                                                              ----
----                                                                      ----
----   OK   = "1111" (reading ok)                                         ----
----   BAD  = "0110" (bad reading)                                        ----
----   INIT = "0001" (reading inited)                                     ----
----   BUSY = "0010" (controller busy)                                    ----
----                                                                      ----
----  To communicate with the memory, besides of the lines for SPI, the   ----
----  following lines are driven:                                         ----
----   fshce_o : Flash_CE of the board. When high, enables communication  ----
----             between FPGA and memory (Chip enable of MUX U20).        ----
----   sfhld_o : Hold# pin of the S25FL. When low, pauses any             ----
----             communication with the memory.                           ----
----                                                                      ----
----                                                                      ----
----  To Do:                                                              ----
----    -                                                                 ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon@inti.gob.ar                         ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2010 Francisco Salomón <fsalomon@inti.gob.ar>          ----
---- Copyright (c) 2010 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      Controller_Test(Top)(Entity and architecture)      ----
---- File name:        Controller_Test.vhdl                               ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   SPI.Devices                                        ----
----                   SPI.Testbench                                      ----
----                   utils.Stdlib                                       ----
---- Target FPGA:      Spartan III (XC3S400aft256-4)                      ----
---- Language:         VHDL                                               ----
---- Wishbone:                                                            ----
---- Synthesis tools:  Xilinx Release 10.1i - xst K.37                    ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
library SPI;
use SPI.Devices.all;
use SPI.Testbench.all;
library utils;
use utils.Stdlib.all;

entity Controller_Test is
   port(
      -- System
      clk_i   : in    std_logic; -- System clock 16 MHz
      rst_i   : in    std_logic; -- Reset
      -- SPI core
      sclk_o  : out   std_logic; -- Serial clock out
      mosi_o  : out   std_logic; -- Master out
      miso_i  : in    std_logic; -- Master in
      ss_o    : out   std_logic; -- Slave chip select
      -- Flash control
      fshce_o : out   std_logic; -- Flash CE of the board
      sfhld_o : out   std_logic; -- Hold# pin of the S25FL
      -- Signaling
      lsig_o  : out   std_logic_vector(3 downto 0);
      spis_o  : out   std_logic_vector(3 downto 0);
      leds_o  : out   std_logic_vector(3 downto 0)
      );

   ------------
   -- Pinout --
   ------------
   attribute LOC        : string;
   attribute PULLUP     : string;

   attribute LOC        of clk_i      : signal is "C10";
   attribute LOC        of rst_i      : signal is "H4";
   attribute LOC        of leds_o     : signal is "B15,C15,C16,D14";
   attribute LOC        of sclk_o     : signal is "R14";
   attribute LOC        of mosi_o     : signal is "P10";
   attribute LOC        of miso_i     : signal is "T14";
   attribute LOC        of ss_o       : signal is "T2";
   attribute LOC        of fshce_o    : signal is "P15";
   attribute LOC        of sfhld_o    : signal is "P13";
   attribute LOC        of lsig_o     : signal is "B8,A7,C7,A6";
   attribute LOC        of spis_o     : signal is "A10,A9,C9,A8";

end entity Controller_Test;

architecture Top of Controller_Test is

   constant SCLK_DIV    : positive:=2;
   constant MAIN_DIV    : positive:=16e6; -- divider for 1Hz
   constant OP_LENGTH   : positive:=CMD_LENGTH+MDID_LENGTH;
   -- LEDs codes
   constant OK_READ_CD  : std_logic_vector(3 downto 0):="1111";
   constant BAD_READ_CD : std_logic_vector(3 downto 0):="0110";
   constant INIT_CD     : std_logic_vector(3 downto 0):="0001";
   constant BUSY_CD     : std_logic_vector(3 downto 0):="0010";

   signal leds_r        : std_logic_vector(3 downto 0):="0000";
   signal core_ena      : std_logic;
   signal txrx_start    : std_logic:='0';
   signal c_busy        : std_logic;
   signal c_irq         : std_logic;
   signal miso : std_logic;
   signal mosi : std_logic;
   signal sclk : std_logic;
   signal ss   : std_logic;
   signal tx_r : std_logic_vector(OP_LENGTH-1 downto 0):=RDID_CMD&DUMMY_ID;
   signal rx_r : std_logic_vector(OP_LENGTH-1 downto 0):=(others=>'0');

begin

   -- A read memory ID opperation each sec
   operation:
   process (clk_i)
      variable cnt : integer range 0 to MAIN_DIV-1;
   begin
      if rising_edge(clk_i) then
         if rst_i='1' then
            cnt:=0;
            txrx_start <= '0';
            leds_r <= (others => '0');
         else
            if c_irq='1' then         -- irq response
               if rx_r(MDID_LENGTH-1 downto 0)=MAN_DEV_ID then -- read id op
                  leds_r <= OK_READ_CD;
               else
                  leds_r <= BAD_READ_CD;
               end if;
            elsif c_busy='1' then
               txrx_start <= '0';     -- controller busy
               leds_r <= BUSY_CD;
            elsif cnt=MAIN_DIV-1 then -- init operation
               cnt:=0;
               txrx_start <= '1';
               leds_r <= INIT_CD;
            else
               cnt:=cnt+1;
            end if;
         end if;
      end if;
   end process operation;

   -- Enable signal from utils library
   do_enable : SimpleDivider
      generic map(
         DIV => SCLK_DIV
         )
      port map(
         clk_i  => clk_i,
         rst_i  => rst_i,
         ena_i  => '1',
         div_o  => core_ena
         );

   -- LEDs register
   leds_o <= leds_r;

   -- fshce_o must be '1' to communicate fpga with s25fl
   fshce_o <= not ss;

   -- SF Hold #
   sfhld_o <= not ss;
   
   -- osc
   lsig_o <= leds_r;
   spis_o(0) <= ss;
   spis_o(1) <= sclk;
   spis_o(2) <= mosi;
   spis_o(3) <= miso;
   
   mosi_o <= mosi;
   miso   <= miso_i;
   sclk_o <= sclk;
   ss_o   <= ss;
   
   -- device under test
   dut : SPI_controller
      generic map(
         SCLK_PHASE   => '0',  SCLK_POLARITY => '0',
         SLAVE_QTT    => 1,    DATA_W        => OP_LENGTH,
         MSB_IS_FIRST => true
         )
      port map(
         clk_i   => clk_i,         rst_i   => rst_i,  ena_i   => core_ena,
         start_i => txrx_start,    tx_i    => tx_r,   rx_o    => rx_r,
         ss_i    => (others=>'0'), busy_o  => c_busy, irq_o   => c_irq,
         miso_i  => miso,          sclk_o  => sclk,   mosi_o  => mosi,
         ss_o(0) => ss
         );

end architecture Top; -- Entity: Controller_Test
