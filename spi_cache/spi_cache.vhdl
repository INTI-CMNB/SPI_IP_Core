------------------------------------------------------------------------------
----                                                                      ----
----  SPI Cache                                                           ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----    Cache for SPI memories                                            ----
----                                                                      ----
----  To Do:                                                              ----
------------------------------------------------------------------------------
---- TODO: Preparar para 8 bits, resolver el problema del envío inicial   ----
------------------------------------------------------------------------------
---- TODO: Si se usa FREAD, hay que incluir un dummy byte probablemente   ----
---- para eso las transacciones convega hacerlas de 8 Bits.               ----
------------------------------------------------------------------------------
---- TODO: Entregar datos mientras se trae el resto de la linea se puede  ----
---- hacer usando word_cnt y line_next en la comparación, en el caso de   ----
---- que el line_hit sea igual que el line_next.                          ----
---- En ese caso, el wait_req solo dependería del hit. Además, un nuevo   ----
---- no hit, debería resetear el proceso de pedido, para que la linea     ----
---- traiga otra cosa. Cuidado loops infinitos entre 2 posiciones, quizá  ----
---- sería mejor que traiga la linea entera , a lo sumo, sí darle lo que  ----
---- se va trayendo (ojo con el ciclo de de espera Write/Read!).          ----
---- También podría predecir instrucción de salto.                        ----
---- Cuando se pida una instrucción ya cacheada mientras se está trayendo ----
---- otra linea, no debería influir en el ciclo de lectura de la SPI.     ----
------------------------------------------------------------------------------
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon en inti gob ar                      ----
----    - Salvador E. Tropea, salvador en inti gob ar                     ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2011 Francisco Salomón <fsalomon en inti gob ar>       ----
---- Copyright (c) 2011 Salvador E. Tropea <salvador en inti gob ar>      ----
---- Copyright (c) 2011 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      SPI_Cache(RTL)                                     ----
---- File name:        spi_cache.vhdl                                     ----
---- Note:             None                                               ----
---- Limitations:      None known                                         ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   SPI                                                ----
----                   mems.devices                                       ----
---- Target FPGA:                                                         ----
---- Language:         VHDL                                               ----
---- Wishbone:                                                            ----
---- Synthesis tools:  Xilinx Release 9.2.03i - xst J.39                  ----
---- Simulation tools: GHDL [Sokcho edition] (0.2x)                       ----
---- Text editor:      SETEdit 0.5.x                                      ----
----                                                                      ----
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library SPI;
use SPI.Devices.all;
use SPI.CacheDevices.all;
library mems;
use mems.devices.all;
library utils;
use utils.Stdlib.all;
use utils.Math.all;

entity SPI_Cache is
   generic(
      -- Cache generics
      CACHE_LINE_L  : positive:=32;    -- Cache data width
      LINES_QTT     : positive:=1;     -- Number of lines
      ADDR_W        : positive:=32;    -- Address bus width
      DATA_W        : positive:=32;    -- Cache data width
      -- Others generics
      BYTE_ADDR     : boolean :=false; -- Byte-oriented address bus
      -- SPI generics
      SCLK_PHASE    : std_logic:='0';  -- Indicates Sclk's edge for sampling
      SCLK_POLARITY : std_logic:='0';  -- Sclk level for no transaction state
      MSB_IS_FIRST  : boolean :=true   -- MSB is sent first
          );
   port(
      -- Clock and reset
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      -- Cache I/O
      adr_i         : in  std_logic_vector(ADDR_W-1 downto 0);
      dat_o         : out std_logic_vector(DATA_W-1 downto 0);
      read_i        : in  std_logic;
      wait_o        : out std_logic;
      -- Debug info
      state_o       : out std_logic_vector(2 downto 0);
      hit_o         : out std_logic;
      comp_o        : out std_logic_vector(LINES_QTT-1 downto 0);
      -- SPI I/O
      ena_i         : in  std_logic;
      miso_i        : in  std_logic;
      sclk_o        : out std_logic;
      mosi_o        : out std_logic;
      ss_o          : out std_logic
        );
end entity SPI_Cache;

architecture RTL of SPI_Cache is

   constant EM_ADDR_W : positive:=24;    -- External memory address width-  2^24 bytes eq 128Megabit
   constant EBDW : natural:=log2(DATA_W/8);  -- Excluded bits due to data width
   constant BRAM_ADDR_W : positive:=log2(LINES_QTT*CACHE_LINE_L); -- Internal BRAM address width
   constant LINE_W : positive:=log2(CACHE_LINE_L); -- Line address width
   constant INT_ADDR_W : integer:=minimum(EM_ADDR_W, ADDR_W);   -- Internal address bus width

   -- Signals for dual port bram
   signal add1: std_logic_vector(BRAM_ADDR_W-1 downto 0):=(others => '0');
   signal add2: std_logic_vector(BRAM_ADDR_W-1 downto 0):=(others => '0');

   signal di  : std_logic_vector(DATA_W-1 downto 0);
   signal do1 : std_logic_vector(DATA_W-1 downto 0);
   signal do2 : std_logic_vector(DATA_W-1 downto 0);
   signal we  : std_logic;

   -- other signals and registers
   signal hit    : std_logic; -- Hit for requested address
   signal start  : std_logic; -- Start transaction for controller
   signal c_busy : std_logic; -- Transaction on course
   signal c_irq  : std_logic; -- Data ready irq from controller

   -- states for read_memory_FSM
   type   state_type is (idle, init, send_addr, data_irq);
   signal rm_state   : state_type:=idle;

   -- data i/o for spi controller
   signal d_to_spi   : std_logic_vector(DATA_W-1 downto 0);
   signal d_from_spi : std_logic_vector(DATA_W-1 downto 0);
   signal ss         : std_logic;

   -- Actual range in memory
   type   actual_type is array(LINES_QTT-1 downto 0) of std_logic_vector(INT_ADDR_W-1 downto 0);
   signal actual_r      : actual_type;
   signal comp_line     : std_logic_vector(LINES_QTT-1 downto 0):=(others => '0');
   signal line_hit      : std_logic_vector(BRAM_ADDR_W-LINE_W-1 downto 0):=(others => '0');
   signal inited_r      : std_logic_vector(LINES_QTT-1 downto 0):=(others => '0');
   signal line_next     : std_logic_vector(BRAM_ADDR_W-LINE_W-1 downto 0):=(others => '0');
   signal word_cnt      : unsigned(LINE_W-1 downto 0):=(others => '0');

   -- Address to external memory
   signal addr_em : std_logic_vector(EM_ADDR_W-1 downto 0):=(others => '0');

   -- Shifted input address if is byte-oriented
   signal addr_sft : std_logic_vector(ADDR_W-1 downto 0):=(others => '0');

begin

   -- Comparators outputs
   comparators_gen:
   for i in comp_line'range generate
       comp_line(i) <= '1' when (addr_sft(INT_ADDR_W-1 downto LINE_W) =
          actual_r(i)(INT_ADDR_W-1 downto LINE_W)) else '0';
   end generate comparators_gen;

   byte_oriented_shift_gen:
   if BYTE_ADDR generate
      addr_sft(ADDR_W-1-EBDW downto 0) <= adr_i(ADDR_W-1 downto EBDW);
   end generate byte_oriented_shift_gen;

   not_byte_oriented_shift_gen:
   if not BYTE_ADDR generate
      addr_sft(ADDR_W-1 downto 0) <= adr_i(ADDR_W-1 downto 0);
   end generate not_byte_oriented_shift_gen;

   -- Check hit for requested address
   hit <= '1' when (unsigned(comp_line and inited_r)/=0) else '0';
   hit_o <= hit;
   comp_o <= comp_line;

   -- Address decoded for external memory
   addr_em(INT_ADDR_W-1 downto LINE_W+EBDW) <= addr_sft(INT_ADDR_W-(1+EBDW) downto LINE_W);

   -- Decode and shift address for bram - One line
   one_line_gen:
   if LINES_QTT=1 generate
      add1 <= std_logic_vector(word_cnt);
      add2 <= addr_sft(BRAM_ADDR_W-1 downto 0);
   end generate one_line_gen;

   -- Decode and shift address for bram - More than one line
   others_line_gen:
   if LINES_QTT>1 generate
      add1 <= line_next & std_logic_vector(word_cnt);
      add2 <= line_hit & addr_sft(LINE_W-1 downto 0);
   end generate others_line_gen;

   line_hit <= std_logic_vector(to_unsigned(log2(sv2uint(comp_line)), line_hit'length));
   wait_o <= (not hit) or ((not ss) or start);
   we <= c_irq when rm_state=data_irq else '0';
   ss_o <= ss;

   -- Read main memory state machine
   read_memory_FSM:
   process (clk_i)
      variable bit_cnt : natural range 0 to 32:=0;
   begin
      if rising_edge(clk_i) then
         if rst_i='1' then
            rm_state <= idle;
            state_o <= "000";
            start <= '0';
         else
            case rm_state is
                 when idle =>
                      if read_i='1' and hit='0' then -- init line request to main memory
                         rm_state <= send_addr;
                         state_o <= "001";
                         if DATA_W=16 then
                            d_to_spi <= READ_CMD & addr_em(EM_ADDR_W-1 downto EM_ADDR_W-8);
                         elsif DATA_W=32 then
                            d_to_spi <= READ_CMD & addr_em(EM_ADDR_W-1 downto 0);
                            rm_state <= init;
                            state_o <= "011";
                         end if;
                         inited_r(sv2uint(line_next)) <= '0';
                         start <= '1';
                         word_cnt <= (others => '0');
                      end if;
                 when send_addr =>
                      if c_busy='1' then
                         if c_irq='1' then
                            rm_state <= init;
                            state_o <= "010";
                         elsif DATA_W=16 then
                            d_to_spi <= addr_em(EM_ADDR_W-9 downto 0);
                         end if;
                      end if;
                 when init =>
                      if c_irq='1' and c_busy='1' then
                         rm_state <= data_irq;
                         state_o <= "011";
                      end if;
                 when data_irq =>
                      if c_irq='1' then
                         if word_cnt<(CACHE_LINE_L-1) then
                            if word_cnt=(CACHE_LINE_L-2) then
                               start <= '0';
                            end if;
                            word_cnt <= word_cnt+1;
                         else
                            actual_r(sv2uint(line_next)) <= addr_sft(INT_ADDR_W-1 downto 0);
                            inited_r(sv2uint(line_next)) <= '1';
                            line_next <= std_logic_vector(unsigned(line_next)+1);
                            rm_state <= idle;
                            state_o <= "000";
                         end if;
                      end if;
                 when others =>
                      rm_state <= idle;
                      state_o <= "000";
            end case;
         end if;
      end if;
   end process read_memory_FSM;

   -- Dual Port Block Ram
   cache_mem: DualPortBRAM
      generic map(
         ADDR_W => BRAM_ADDR_W,  DATA_W    => DATA_W,
         SIZE   => LINES_QTT*CACHE_LINE_L, FALL_EDGE => true)
      port map(
         clk_i  => clk_i,      we_i   => we,
         add1_i => add1,       add2_i => add2,
         di_i   => d_from_spi, do2_o  => dat_o);

   -- SPI Controller
   -- Transaction spi data length equal to the bus data size
   spi : SPI_controller
      generic map(
         SCLK_PHASE   => SCLK_PHASE,  SCLK_POLARITY => SCLK_POLARITY,
         SLAVE_QTT    => 1,           DATA_W        => DATA_W,
         MSB_IS_FIRST => MSB_IS_FIRST)
      port map(
         clk_i   => clk_i,    rst_i  => rst_i,        ena_i => ena_i,
         start_i => start,    tx_i   => d_to_spi,     rx_o  => d_from_spi,
         ss_i    => (others=>'0'),
         busy_o  => c_busy,   irq_o  => c_irq,        miso_i=> miso_i,
         sclk_o  => sclk_o,   mosi_o => mosi_o,       ss_o(0) => ss
         );

end architecture RTL; -- Entity: SPI_Cache

