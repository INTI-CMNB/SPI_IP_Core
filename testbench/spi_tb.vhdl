------------------------------------------------------------------------------
----                                                                      ----
----  Testbench for SPI WISHBONE                                          ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----   Testbench for SPI WISHBONE interface using the wb_handler          ----
----  component and an S25FL flash memory simulator. It creates and test  ----
----  two instances of the core with diferent FIFO's depth.               ----
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
---- Design unit:      SPI_TB(Bench)                                      ----
---- File name:        spi_tb.vhdl                                        ----
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
----                   wb_handler.WishboneTB                              ----
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
library wb_handler;
use wb_handler.WishboneTB.all;

entity SPI_TB is
end entity SPI_TB;

architecture Bench of SPI_TB is

   constant FREQUENCYHZ : positive:=50e6;-- frequency in Hz
   constant ENA_DIV     : positive:=4;   -- enable clk divisor for controller
   constant SQTT        : positive:=4;   -- slave quantity
   constant SSBQTT      : positive:=2;   -- ss bits quantity
   constant SSELECTED   : natural :=3;   -- slave selected from 0 to SQTT-1

   -- type for data transaction array; cmd+id = 6 bytes
   type d_trans is array(0 to 5) of
        std_logic_vector(7 downto 0);
   signal tx_cmd   : d_trans:=(0 => RDID_CMD, others => x"00");
   -- MAN_DEV_ID = x"0120180301"
   signal rx_hoped : d_trans:=(5 => x"01", 4 => x"03", 3 => x"18",
                               2 => x"20", 1 => x"01", 0 => (others => 'Z'));

   -- type for SPI master out lines
   type spi_master_o_type is record
      sclk : std_logic;
      mosi : std_logic;
      ss   : std_logic_vector(SQTT-1 downto 0);
   end record;

   -- signals for controllers
   signal ena        : std_logic;
   signal miso_d1    : std_logic;
   signal miso_d6    : std_logic;
   signal spi_mo_d1  : spi_master_o_type;
   signal spi_mo_d6  : spi_master_o_type;
   signal dr_irq     : std_logic;
   signal dr_irq_d1  : std_logic;
   signal dr_irq_d6  : std_logic;
   signal oe_irq     : std_logic;
   signal oe_irq_d1  : std_logic;
   signal oe_irq_d6  : std_logic;

   -- signals for WISHBONE
   signal wbi        : wb_bus_i_type;
   signal wbo        : wb_bus_o_type;
   signal wb_rst     : std_logic:='1';
   signal wb_clk     : std_logic;
   signal wb_dati    : std_logic_vector(7 downto 0);
   signal wb_dato    : std_logic_vector(7 downto 0);
   signal wb_adr     : std_logic_vector(7 downto 0);
   signal adr_o1     : std_logic_vector(0 downto 0);
   signal wb_we      : std_logic;
   signal wb_cyc     : std_logic;
   signal wb_stb     : std_logic;
   signal wb_stb_d1  : std_logic;     -- strobe for dut_d1
   signal wb_stb_d6  : std_logic;     -- strobe for dut_d6
   signal wb_ack     : std_logic;
   signal wb_ack_d1  : std_logic;     -- ack for dut_d1
   signal wb_ack_d6  : std_logic;     -- ack for dut_d6
   signal wb_dato_d1 : std_logic_vector(7 downto 0); -- dut_d1 dout
   signal wb_dato_d6 : std_logic_vector(7 downto 0); -- dut_d6 dout
   signal test_d1    : boolean:=true; -- signal for intercon
   -- stop simulation
   signal stop_sim   : std_logic:= '0';

   -- function to get string integer image
   function str(i:integer) return string is
   begin
      return integer'image(i);
   end str;

   -- procedure for spi_wb registers checking
   procedure CheckSPIWBReg(
      constant ADDRESS       : std_logic_vector(7 downto 0);
      signal   wbi           : in wb_bus_i_type;
      signal   wbo           : out wb_bus_o_type;
      constant VAL_HOPED     : std_logic_vector(7 downto 0);
      constant FAIL_TXT      : string;
      constant MASK          : in std_logic_vector(7 downto 0)) is
   begin
      WBRead(ADDRESS,wbi,wbo);
      assert (MASK and wbi.dato)=(MASK and VAL_HOPED) report FAIL_TXT &
         " [x" & hstr(wbi.dato)&" instead of x"&hstr(val_hoped) & "]"
         severity failure;
   end procedure CheckSPIWBReg;

   -- procedure for device status checking
   procedure CheckStatus(
      signal   wbi           : in wb_bus_i_type;
      signal   wbo           : out wb_bus_o_type;
      constant VAL_HOPED     : std_logic_vector(7 downto 0);
      constant FAIL_TXT      : string;
      constant MASK          : in std_logic_vector(7 downto 0):=
                               (others => '1')) is
   begin
      CheckSPIWBReg(STATUS, wbi, wbo, VAL_HOPED,"STATUS: Invalid value after"&
                    " " &FAIL_TXT, MASK);
   end procedure CheckStatus;


begin

   -- clock and reset signals from utils library
   do_clk_and_rst: SimpleClock
      generic map(FREQUENCY => FREQUENCYHZ)
      port map(
         clk_o  => wb_clk, nclk_o => open, rst_o => wb_rst,
         stop_i => stop_sim);

   -- enable signal from utils library
   do_enable: SimpleDivider
      generic map(DIV => ENA_DIV)
      port map(
         clk_i => wb_clk, rst_i => wb_rst, div_o => ena);

   -- connect the records to the individual signals
   wbi.clk  <= wb_clk;
   wbi.rst  <= wb_rst;
   wbi.dato <= wb_dato;
   wbi.ack  <= wb_ack;

   wb_stb   <= wbo.stb;
   wb_we    <= wbo.we;
   wb_adr   <= wbo.adr;
   wb_dati  <= wbo.dati;

   -- address connection
   adr_o1 <= wb_adr(0 downto 0);

   -- strobe decode
   wb_stb_d1 <= wb_stb when test_d1 else '0';
   wb_stb_d6 <= '0' when test_d1 else wb_stb;

   -- mux for ack
   wb_ack  <= wb_ack_d1 when test_d1 else wb_ack_d6;
   -- mux for slaves data outputs
   wb_dato <= wb_dato_d1 when test_d1 else wb_dato_d6;
   -- mux for irqs
   dr_irq  <= dr_irq_d1 when test_d1 else dr_irq_d6;
   oe_irq  <= oe_irq_d1 when test_d1 else oe_irq_d6;

   -- device under test with FIFO_DEPTH=1
   dut_d1 : SPI_WB
      generic map(
         FIFO_ADDR_W   => 1,     FIFO_DEPTH    => 1,
         DR_IRQ_ALWS   => true,  DATA_W        => 8,
         SLAVE_QTT     => SQTT,  SS_BITS_QTT   => SSBQTT,
         MSB_IS_FIRST  => true
         )
      port map(
         -- WISHBONE
         wb_clk_i => wb_clk,      wb_rst_i => wb_rst,     wb_adr_i => adr_o1,
         wb_dat_i => wb_dati,     wb_dat_o => wb_dato_d1, wb_we_i  => wb_we,
         wb_stb_i => wb_stb_d1,   wb_ack_o => wb_ack_d1,
         -- Controller
         ena_i    => ena,            miso_i   => miso_d1,
         sclk_o   => spi_mo_d1.sclk, mosi_o   => spi_mo_d1.mosi,
         ss_o     => spi_mo_d1.ss,
         -- Interruptions Request
         dr_irq_o => dr_irq_d1,   oe_irq_o => oe_irq_d1);

   -- device under test with FIFO_DEPTH=6
   dut_d6 : SPI_WB
      generic map(
         FIFO_ADDR_W   => 3,     FIFO_DEPTH    => 6,
         DR_IRQ_ALWS   => false, DATA_W        => 8,
         SLAVE_QTT     => SQTT,  SS_BITS_QTT   => SSBQTT,
         MSB_IS_FIRST  => true
         )
      port map(
         -- WISHBONE
         wb_clk_i => wb_clk,      wb_rst_i => wb_rst,     wb_adr_i => adr_o1,
         wb_dat_i => wb_dati,     wb_dat_o => wb_dato_d6, wb_we_i  => wb_we,
         wb_stb_i => wb_stb_d6,   wb_ack_o => wb_ack_d6,
         -- Controller
         ena_i    => ena,            miso_i   => miso_d6,
         sclk_o   => spi_mo_d6.sclk, mosi_o   => spi_mo_d6.mosi,
         ss_o     => spi_mo_d6.ss,
         -- Interruptions Request
         dr_irq_o => dr_irq_d6,   oe_irq_o => oe_irq_d6);

   -- memory simulator, dut_d1 slave
   mem_sim_d1 : S25FL_sim
      port map(
         sck_i => spi_mo_d1.sclk,  si_i => spi_mo_d1.mosi,
         so_o  => miso_d1,         cs_i => spi_mo_d1.ss(SSELECTED));

   -- memory simulator, dut_d6 slave
   mem_sim_d6 : S25FL_sim
      port map(
         sck_i => spi_mo_d6.sclk,  si_i => spi_mo_d6.mosi,
         so_o  => miso_d6,         cs_i => spi_mo_d6.ss(SSELECTED));

   -- simulate transaction
   --   status       x|x|x|oer_tx |oer_rx |rx_rdy|tx_free|busy

   -- testbench for fifo depth=1 and depth=6
   sim_transaction:
   process
   begin
      outwrite("* Init testbench");
      ------------------------------------------------------------------------
      -- testbench for fifo depth=1
      ------------------------------------------------------------------------
      outwrite("* Test for SPI WISHBONE interface with:");
      outwrite("  FIFO_ADDR_W=1");
      outwrite("  FIFO_DEPTH=1");
      outwrite("  DR_IRQ_ALWS=true");
      -- check transaction
      outwrite("* Checking transaction...");
      wait until falling_edge(wb_rst);
      -- check initial status state; only tx_free must be set
      CheckStatus(wbi,wbo,TX_FREE, "reset");
      -- select slave
      WBWrite(CONTROL,std_logic_vector(to_unsigned(SSELECTED,8)),
              wbi,wbo,true);-- wait until clk rising edge
      -- set first byte; after that all status bits must be '0'
      WBWrite(TX_BUFFER,tx_cmd(0),wbi,wbo,true);
      CheckStatus(wbi,wbo, (others => '0'), "tx writing #0");
      -- wait for controller start transaction; after that, only busy
      -- and tx_free bits must be '1'
      wait until falling_edge(ena);
      CheckStatus(wbi,wbo, TX_FREE or BUSY, "controller start");
      for i in 1 to (tx_cmd'length-1) loop
            WBWrite(TX_BUFFER,tx_cmd(i),wbi,wbo,true);
          CheckStatus(wbi,wbo,BUSY,"tx writing #"&str(i));
          -- wait for data ready irq(wait for clk edge,so tx free must be set)
          wait until rising_edge(wb_clk) and (dr_irq='1');
          -- tx_free, data_ready and busy bits must be '1'
          CheckStatus(wbi,wbo, DATA_READY or TX_FREE or BUSY,
                      "data ready irq #" & str(i-1));
          -- check data arrived
          CheckSPIWBReg(RX_BUFFER,wbi,wbo, rx_hoped(i-1),
                        "RX_D1: Invalid byte #"&str(i-1), (others => '1'));
          -- check data_ready bit cleaning after reading
          CheckStatus(wbi,wbo, TX_FREE or BUSY, "rx reading #" &str(i-1));
      end loop;
      -- wait for the last data ready irq; other status are expected
      wait until rising_edge(wb_clk) and (dr_irq='1');
      -- busy bit must be '0'; tx_free and data_ready bits must be '1'
      CheckStatus(wbi,wbo, DATA_READY or TX_FREE, "data ready irq #"&
                  str(tx_cmd'length-1));
      -- check data arrived
      CheckSPIWBReg(RX_BUFFER,wbi,wbo, rx_hoped(rx_hoped'length-1), "RX_D1: "&
                    "Invalid byte #"&str(rx_hoped'length-1),(others => '1'));
      -- check data_ready bit cleaning
      CheckStatus(wbi,wbo, TX_FREE, "rx reading #"&str(rx_hoped'length-1));
      -- check errors generation
      outwrite("* Checking errors generation...");
      -- tx overflow error
      -- init a new transaction for simulate errors
      WBWrite(TX_BUFFER,RDID_CMD,wbi,wbo,true);
      -- set a new data, tx overflow error must be generated
      -- (never tx buffer will be free after only a clock cycle for depth=1)
      -- check error generation; don't wait a clock cycle to check it
      WBWrite(TX_BUFFER,(others => '0'),wbi,wbo,false);
      assert oe_irq='1' report "OE TX IRQ: Invalid state after error "
         &"condition" severity failure;
      -- oer_tx bit must be set; others bits depends on the clock enable
      CheckStatus(wbi,wbo,(others => '1'),"tx overflow error", OETX);
      -- check oer_tx bit cleaning
      CheckStatus(wbi,wbo,(others => '0'),"tx overflow error cleanign", OETX);
      -- rx overflow error
      -- set something on tx buffer and so generate rx overflow error
      if wb_dato(TX_FREE_BIT)='1' then
         WBWrite(TX_BUFFER,(others => '0'),wbi,wbo,true);
      end if;
      -- wait for data ready irq
      wait until rising_edge(wb_clk) and (dr_irq='1');
      -- wait for the next data ready irq without reading rx buffer
      wait until rising_edge(wb_clk) and (dr_irq='1');
      -- check oe irq
      assert oe_irq='1' report "OE RX IRQ: Invalid state after error "
         &"condition" severity failure;
      -- check status; oer_rx, data_ready and tx_free must be '1'
      CheckStatus(wbi,wbo, OERX or DATA_READY or TX_FREE,
                  "rx overflow error");
      -- after reading, oer_rx bit must be '0'
      CheckStatus(wbi,wbo, DATA_READY or TX_FREE, "error reading");
      -- clean rx_unread bit; check return to initial state; only tx_free
      -- bit must be '1'
      WBRead(RX_BUFFER,wbi,wbo);
      CheckStatus(wbi,wbo, TX_FREE, "idle condition setting");
      ------------------------------------------------------------------------
      -- testbench for fifo depth=6
      ------------------------------------------------------------------------
      test_d1 <= false;
      outwrite("* Test for SPI WISHBONE interface with:");
      outwrite("  FIFO_ADDR_W = 3");
      outwrite("  FIFO_DEPTH  = 6");
      outwrite("  DR_IRQ_ALWS = false");
      -- check transaction
      outwrite("* Checking transaction...");
      -- check initial status state; only tx_free must be set
      CheckStatus(wbi,wbo, TX_FREE, "reset");
      -- select slave
      WBWrite(CONTROL, std_logic_vector(to_unsigned(SSELECTED,8)),
              wbi,wbo,true);-- wait until clk rising edge
      -- loop for send data command
      for i in tx_cmd'range loop
          WBWrite(TX_BUFFER,tx_cmd(i),wbi,wbo,true);
      end loop;
      -- check start; busy tx_free bits must be '1'
      CheckStatus(wbi,wbo,TX_FREE or BUSY,"data writing");
      -- wait for data ready
      wait until rising_edge(wb_clk) and (dr_irq='1');
      -- tx_free data_ready bits must be '1'; busy must '0'
      CheckStatus(wbi,wbo,DATA_READY or TX_FREE,"data ready irq");
      -- wait a delay cycle for read more than one fifo position
      WBRead(RX_BUFFER,wbi,wbo); -- fake reading
      -- loop for test data arrived; MAN_DEV_ID = x"0120180301"
      for i in rx_hoped'range loop
          CheckSPIWBReg(RX_BUFFER,wbi,wbo, rx_hoped(i),"RX_D6: Invalid "&
                        "byte #"&str(i), (others => '1'));
       end loop;
      -- check data_ready bit cleaning; only tx_free must be '1'
      CheckStatus(wbi,wbo,TX_FREE, "data reading");
      -- init a new transaction for simulate errors
      outwrite("* Checking errors generation...");
      -- loop for send data command
      for i in tx_cmd'range loop
          WBWrite(TX_BUFFER,tx_cmd(i),wbi,wbo,true);
      end loop;
      wait until ena='1'; -- then, the next data will be latched too
      WBWrite(TX_BUFFER,(others => '0'),wbi,wbo,true);
      -- check error generation; don't wait a clock cycle to check it
      WBWrite(TX_BUFFER,(others => '0'),wbi,wbo,false);
      assert oe_irq='1' report "OE TX IRQ: Invalid state after error "
         &"condition" severity failure;
      -- oer_tx bit must be set; others bits depends on the clock enable
      CheckStatus(wbi,wbo,(others => '1'),"tx overflow error",OETX);
      -- check oer_tx bit cleaning
      CheckStatus(wbi,wbo,(others => '0'),"tx overflow error cleanign",OETX);
      -- rx overflow error
      -- wait for data ready irq
      wait until rising_edge(wb_clk) and (dr_irq='1');
      -- due to 7 data were set without a reading data arrived, rx overflow
      -- error must be generated
      assert oe_irq='1' report "OE RX IRQ: Invalid state after error "
         &"condition" severity failure;
      -- check status; oer_rx, data_ready and tx_free must be '1'
      CheckStatus(wbi,wbo,OERX or DATA_READY or TX_FREE,"rx overflow error");
      -- after reading, oer_rx bit must be '0'
      CheckStatus(wbi,wbo, DATA_READY or TX_FREE, "error reading");
       --Stopping test
      stop_sim <= '1';
      outwrite("* Testbench OK");
      wait;
   end process sim_transaction;
   
end architecture Bench; -- Entity: SPI_TB 
