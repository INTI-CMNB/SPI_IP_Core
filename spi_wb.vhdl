------------------------------------------------------------------------------
----                                                                      ----
----  SPI master controller with WISHBONE slave interface                 ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----   This is a WISHBONE compatible interface for an SPI master          ----
----  controller. It has transmition and reception FIFOs and status       ----
----  and control registers (see Address Table below), addressable        ----
----  via WISHBONE. Besides, it has interruption request for data         ----
----  arrived and overflow error.                                         ----
----   The SPI transaction size is equivalent to the WISHBONE data        ----
----  bus width and is configurable via a generic.                        ----
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
---- Design unit:      SPI_WB(Interface) (Entity and architecture)        ----
---- File name:        spi_wb.vhdl                                        ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   SPI.Devices                                        ----
----                   utils.Stdlib                                       ----
----                   mems.devices                                       ----
---- Target FPGA:      Spartan 3A (XC3S400-FT256)                         ----
---- Language:         VHDL                                               ----
---- Wishbone:         SLAVE (rev B.3)                                    ----
---- Synthesis tools:  Xilinx Release 10.1i - xst K.37                    ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Wishbone Datasheet                                                   ----
----                                                                      ----
----  1 Revision level                      B.3                           ----
----  2 Type of interface                   SLAVE                         ----
----  3 Defined signal names                RST_I => wb_rst_i             ----
----                                        CLK_I => wb_clk_i             ----
----                                        ADR_I => wb_adr_i             ----
----                                        DAT_I => wb_dat_i             ----
----                                        DAT_O => wb_dat_o             ----
----                                        WE_I  => wb_we_i              ----
----                                        ACK_O => wb_ack_o             ----
----  4 ERR_I                               Unsupported                   ----
----  5 RTY_I                               Unsupported                   ----
----  6 TAGs                                None                          ----
----  7 Port size                           8-bit (*)                     ----
----  8 Port granularity                    8-bit                         ----
----  9 Maximum operand size                8-bit                         ----
---- 10 Data transfer ordering              N/A                           ----
---- 11 Data transfer sequencing            Undefined                     ----
---- 12 Constraints on the CLK_I signal     None                          ----
----                                                                      ----
---- (*) Could be configured via DATA_W generic                           ----
----                                                                      ----
---- Notes: SEL_O is not needed because size==granularity                 ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library SPI;
use SPI.Devices.all;
library utils;
use utils.Stdlib.all;
library mems;
use mems.devices.all;

entity SPI_WB is
   generic(
      -- FIFO
      FIFO_ADDR_W   : natural:=3;     -- Address width
      FIFO_DEPTH    : natural:=6;     -- Size(less or equal to 2^FIFO_ADDR_W)
      -- SPI Generics
      SCLK_PHASE    : std_logic:='0'; -- SClk phase
      SCLK_POLARITY : std_logic:='0'; -- SClk polarity
      SLAVE_QTT     : positive:=2;    -- Number of selectable slave devices
      SS_BITS_QTT   : positive:=1;    -- Number of bits for slave select
      MSB_IS_FIRST  : boolean:=false; -- MSB is sent first
      -- SPI and WISHBONE
      DR_IRQ_ALWS   : boolean:=false; -- Irqs after each data ready event
      DATA_W        : positive:=8     -- Bus, fifo and transaction width
      );
   port(
      -- WISHBONE
      wb_clk_i      : in  std_logic;
      wb_rst_i      : in  std_logic;
      wb_adr_i      : in  std_logic_vector(0 downto 0);
      wb_dat_i      : in  std_logic_vector(DATA_W-1 downto 0);
      wb_dat_o      : out std_logic_vector(DATA_W-1 downto 0);
      wb_we_i       : in  std_logic;
      wb_stb_i      : in  std_logic;
      wb_ack_o      : out std_logic;
      -- Controller
      ena_i         : in  std_logic;
      miso_i        : in  std_logic;
      sclk_o        : out std_logic;
      mosi_o        : out std_logic;
      ss_o          : out std_logic_vector(SLAVE_QTT-1 downto 0);
      -- Data ready and overflow error interruptions request
      dr_irq_o      : out std_logic;
      oe_irq_o      : out std_logic
      );
end entity SPI_WB;

architecture Interface of SPI_WB is
   -- Address Table
   --------------------------------------------------------------------------
   --    Register | Address | Mode |                  Content                |
   --------------------------------------------------------------------------
   -- tx_fifo_in  |    0    |   w  |           (data to transmit)            |
   -- rx_fifo_out |    0    |   r  |             (data received)             |
   --  control(*) |    1    |   w  | x|.. | x    |   ss |     ...      |ss   |
   --    status   |    1    |   r  | x|x|x|oer_tx|oer_rx|rx_rdy|tx_free|busy |
   --------------------------------------------------------------------------
   -- (*) ss bits quantity depends on the SS_BITS_QTT generic.

   -- status and control registers
   signal s_reg          : std_logic_vector(DATA_W-1 downto 0):=(others=>'0');
   signal control_r      : std_logic_vector(DATA_W-1 downto 0):=(others=>'0');
   -- decoded WISHBONE signals
   signal write_wb_ctrl  : std_logic;
   signal read_wb_status : std_logic;
   signal write_wb_tx    : std_logic;
   signal read_wb_rx     : std_logic;
   -- signals for fifo input mem
   signal fifo_i_full    : std_logic;
   signal fifo_i_avail   : std_logic;
   signal fifo_i_datao   : std_logic_vector(DATA_W-1 downto 0);
   signal fifo_i_write   : std_logic;
   signal fifo_i_read    : std_logic;
   -- signals for fifo output mem
   signal fifo_o_full    : std_logic;
   signal fifo_o_avail   : std_logic;
   signal fifo_o_datai   : std_logic_vector(DATA_W-1 downto 0);
   signal fifo_o_datao   : std_logic_vector(DATA_W-1 downto 0);
   signal fifo_o_write   : std_logic;
   signal fifo_o_read    : std_logic;
   signal fifo_o_empty   : std_logic;
   -- other signals and registers
   signal start          : std_logic;      -- start transaction for controller
   signal c_busy         : std_logic;      -- transaction on course
   signal tx_free        : std_logic;      -- tx fifo is not full
   signal c_irq          : std_logic;      -- data ready irq from controller
   signal rx_unread      : std_logic;      -- data available in rx fifo
   signal oer_rx_r       : std_logic:='0'; -- rx fifo overflow error
   signal oer_tx_r       : std_logic:='0'; -- tx fifo overflow error
   signal c_irq_d_r      : std_logic:='0'; -- c_irq delayed a clock cycle
   signal oer_rx_irq_r   : std_logic:='0'; -- rx fifo overflow error irq pulse
   signal oer_tx_irq     : std_logic;      -- tx fifo overflow error irq pulse
begin
   -- decoded WISHBONE signals
   write_wb_ctrl  <=  wb_stb_i and wb_we_i and wb_adr_i(0);
   write_wb_tx    <=  wb_stb_i and wb_we_i and (not wb_adr_i(0));
   read_wb_status <=  wb_stb_i and (not wb_we_i) and wb_adr_i(0);
   read_wb_rx     <=  wb_stb_i and (not wb_we_i) and (not wb_adr_i(0));

   -- control register
   decode_ss_gen:
   if SLAVE_QTT>1 generate
      control_reg:
      process (wb_clk_i)
      begin
         if rising_edge(wb_clk_i) then
            if wb_rst_i='1' then
               control_r <= (others => '0');
            elsif write_wb_ctrl='1' then
               control_r <= wb_dat_i;
            end if;
         end if;
      end process control_reg;
   end generate decode_ss_gen;

   -- overflow errors
   -- register for rx overflow error
   overflow_error_rx:
   process (wb_clk_i)
   begin
      if rising_edge(wb_clk_i) then
         if wb_rst_i='1' then
            oer_rx_r <= '0';
         elsif oer_rx_irq_r='1' then
            oer_rx_r <= '1';
         elsif read_wb_status='1' then
            oer_rx_r <= '0';
         end if;
      end if;
   end process overflow_error_rx;
   -- register for tx overflow error
   overflow_error_tx:
   process (wb_clk_i)
   begin
      if rising_edge(wb_clk_i) then
         if wb_rst_i='1' then
            oer_tx_r <= '0';
         elsif oer_tx_irq='1' then
            oer_tx_r <= '1';
         elsif read_wb_status='1' then
            oer_tx_r <= '0';
         end if;
      end if;
   end process overflow_error_tx;

   -- Fifo input memory
   fifo_i: Fifo
   generic map(
      ADDR_W => FIFO_ADDR_W, DATA_W => DATA_W, DEPTH => FIFO_DEPTH )
   port map(
      clk_i   => wb_clk_i,
      rst_i   => wb_rst_i,
      we_i    => fifo_i_write,
      re_i    => fifo_i_read,
      datai_i => wb_dat_i,
      datao_o => fifo_i_datao,
      full_o  => fifo_i_full,
      avail_o => fifo_i_avail,
      empty_o => open);

   -- fifo input write; this prevents writing operation when memory is full
   fifo_i_write <= write_wb_tx and (not fifo_i_full);
   -- fifo input read
   fifo_i_read  <= fifo_i_avail and ((not c_busy and ena_i) or c_irq);
   -- start signal for controller
   start <= fifo_i_avail;
   -- tx_free flag
   tx_free <= not fifo_i_full;

   -- Fifo output memory
   fifo_o: Fifo
   generic map(
      ADDR_W => FIFO_ADDR_W, DATA_W => DATA_W, DEPTH => FIFO_DEPTH )
   port map(
      clk_i   => wb_clk_i,
      rst_i   => wb_rst_i,
      we_i    => fifo_o_write,
      re_i    => fifo_o_read,
      datai_i => fifo_o_datai,
      datao_o => fifo_o_datao,
      full_o  => fifo_o_full,
      avail_o => fifo_o_avail,
      empty_o => fifo_o_empty);

   -- fifo output read; this prevents reading operation when memory is empty
   fifo_o_read  <= read_wb_rx and fifo_o_avail;
   -- fifo output write; this prevents writing operation when memory is full
   fifo_o_write <= c_irq and not(fifo_o_full);
   -- WISHBONE data output
   wb_dat_o  <= s_reg when wb_adr_i(0)='1' else fifo_o_datao;

   -- data ready interrupt
   -- signal for data ready irq
   -- use a cycle delay for c_irq due to delay in fifo initial load
   ffd_irq:
   process (wb_clk_i)
   begin
      if rising_edge(wb_clk_i) then
         if wb_rst_i='1' then
            c_irq_d_r <= '0';
         else
            c_irq_d_r <= c_irq;
         end if;
      end if;
   end process ffd_irq;
   -- generates dr irq after each data ready
   dr_irq_always_gen:
   if DR_IRQ_ALWS generate
      dr_irq_o <= c_irq_d_r;
   end generate dr_irq_always_gen;
   -- generates dr irq only after transaction's end
   dr_irq_not_always_gen:
   if not(DR_IRQ_ALWS) generate
      dr_irq_o <= c_irq_d_r and not(c_busy);
   end generate dr_irq_not_always_gen;

   -- data arrived from spi slave still unread
   rx_unread <= not fifo_o_empty;

   -- status register
   s_reg(4) <= oer_tx_r;
   s_reg(3) <= oer_rx_r;
   s_reg(2) <= rx_unread;
   s_reg(1) <= tx_free;
   s_reg(0) <= c_busy;

   -- overflow irq pulse
   -- overflow in rx fifo
   -- use a cycle delay for the error condition
   ffd_or_rx_irq:
   process (wb_clk_i)
   begin
      if rising_edge(wb_clk_i) then
         if wb_rst_i='1' then
            oer_rx_irq_r <= '0';
         else
            oer_rx_irq_r <= c_irq and fifo_o_full;
         end if;
      end if;
   end process ffd_or_rx_irq;
   -- overflow in tx fifo
   oer_tx_irq <= fifo_i_full and write_wb_tx;
   -- overflow irq output pulse
   oe_irq_o <= oer_rx_irq_r or oer_tx_irq;
   
   -- ack signal connected to the strobe
   wb_ack_o <= wb_stb_i;

   -- spi controller
   -- the transaction spi data length equal to the bus data size
   spi : SPI_controller
      generic map(
         SCLK_PHASE  => SCLK_PHASE,  SCLK_POLARITY => SCLK_POLARITY,
         SLAVE_QTT   => SLAVE_QTT,   SS_BITS_QTT   => SS_BITS_QTT,
         DATA_W      => DATA_W,      MSB_IS_FIRST  => MSB_IS_FIRST
         )
      port map(
         clk_i   => wb_clk_i, rst_i  => wb_rst_i,     ena_i => ena_i,
         start_i => start,    tx_i   => fifo_i_datao, rx_o  => fifo_o_datai,
         ss_i    => control_r(SS_BITS_QTT-1 downto 0),
         busy_o  => c_busy,   irq_o  => c_irq,        miso_i=> miso_i,
         sclk_o  => sclk_o,   mosi_o => mosi_o,       ss_o  => ss_o
         );
         
end architecture Interface; -- Entity: SPI_WB

