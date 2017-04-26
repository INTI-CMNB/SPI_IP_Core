------------------------------------------------------------------------------
----                                                                      ----
----  Simulator of SPI slave S25lf                                        ----
----                                                                      ----
----  This file is part FPGA Libre project http://fpgalibre.sf.net/       ----
----                                                                      ----
----  Description:                                                        ----
----    Simulator of S25FL flash; this is an spi slave device with msb    ----
----  first, mode 0 or 3.                                                 ----
----    It implements RDID (Read Identification), READ and FREAD (fast    ----
----  read) commands.                                                     ----
----                                                                      ----
----  To Do:                                                              ----
----  -                                                                   ----
----                                                                      ----
----  Author:                                                             ----
----    - Francisco Salomón, fsalomon en inti.gob.ar                      ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Copyright (c) 2010 Francisco Salomón <fsalomon en inti.gob.ar>       ----
---- Copyright (c) 2010 Instituto Nacional de Tecnología Industrial       ----
----                                                                      ----
---- Distributed under the GPL v2 or newer license                        ----
----                                                                      ----
------------------------------------------------------------------------------
----                                                                      ----
---- Design unit:      S25FL_sim                                          ----
---- File name:        s25fl_simulator.vhdl                               ----
---- Note:             None                                               ----
---- Limitations:      Implements only some commands                      ----
---- Errors:           None known                                         ----
---- Library:          None                                               ----
---- Dependencies:     IEEE.std_logic_1164                                ----
----                   IEEE.numeric_std                                   ----
----                   SPI.Testbench                                      ----
----                   utils.Str                                          ----
----                   utils.StdIO                                        ----
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
library std;
use std.textio.all;
library SPI;
use SPI.Testbench.all;
library utils;
use utils.Str.all;
use utils.StdIO.all;

use utils.Stdlib.all;

entity S25FL_sim is
   generic(
     MEM_SIZE    : natural:=16777216; -- Memory size, in bytes
     DATA_FILE   : string:="testbench/data_file.dat" -- Memory content
          );
   port(
      sck_i      : in  std_logic;
      so_o       : out std_logic;
      si_i       : in  std_logic;
      cs_i       : in  std_logic:='1'
        );
end entity S25FL_sim;

architecture Command of S25FL_sim is
   signal t_change_cs : time:=0  ns; -- Stores time in which cs changes
   signal t_sck_h     : time:=0  ns; -- Stores sck high time
   signal t_sck_l     : time:=0  ns; -- Stores sck low time
   signal cmd_r : std_logic_vector(7 downto 0);  -- Register for command arrived
   signal adr_r : std_logic_vector(23 downto 0); -- Register for address arrived
   signal tx_r  : std_logic_vector(7 downto 0):=
                   (others => 'Z');              -- tx register
   signal rx_r  : std_logic_vector(7 downto 0):=
                   (others => '0');              -- rx register
   signal si_delayed    : std_logic;   -- Signal for setup time input check
   type   transf_state_type is (cmd, addr, dummy, data);
   signal tranf_state : transf_state_type:=cmd; -- states for transfer
      
begin

   -- simulate setup time
   si_delayed <= si_i after TDIS;

   -- command processing
   proc_command:
   process
      --variable tranf_state : transf_state_type:=cmd; -- states for transfer
      variable bit_cnt     : natural range 0 to 7:=0;
      variable id_cnt      : natural:=0; -- id byte count
      variable adr_cnt     : natural:=0; -- address byte count
      variable data_a      : slv8_array(0 to MEM_SIZE-1):=
        (others => (others => '1'));
      variable adr_os      : natural:=0; -- Address offset
   begin
      wait until falling_edge(cs_i);
      id_cnt:=0;
      adr_cnt:=0;
      bit_cnt:=0;
      t_change_cs <= now;
      tranf_state<=cmd;
      wait for 1 fs;
      wait for TV;     -- Output valid data delay
      so_o <= tx_r(7); -- MSbit first
      -- Enter loop for transactions
      while (cs_i='0') loop
         while bit_cnt<=7 loop
            -----------------------
            -- SClk Rising edge  --
            -----------------------
            wait until rising_edge(sck_i) or (cs_i='1');
            if cs_i='1' then exit; end if;
            if tranf_state=cmd and bit_cnt=0 then -- Mess. chip select setup time
               assert (now-t_change_cs)>TCSS report "CS setup time too short"
                  severity failure;
            else
               assert (now-t_sck_l)>TWL report "SCKL Low time too short"
                 severity failure;
            end if;
            t_sck_h <= now;
            wait for TDIH;   -- Delay for hold time signal check
            rx_r(7-bit_cnt) <= si_delayed;
            -----------------------
            -- SClk Falling edge --
            -----------------------
            wait until falling_edge(sck_i) or (cs_i='1');
            if cs_i='1' then
               exit;
               --report "******************************* CS";
            end if;
            --report "Bit "&integer'image(bit_cnt);
            assert (now-t_sck_h)>TWH report "SCKL High time too short"
               severity failure;
            t_sck_l <= now;
            wait for TV; -- Output valid data delay
            ---------------------------
            -- Evaluate transaction  --
            ---------------------------
            if bit_cnt=7 then
               bit_cnt:=0;
               if tranf_state=cmd then  -- First byte is the command; check it
                  cmd_r <= rx_r;
                  wait for 1 fs;
               end if;
               case cmd_r is -- Set next byte to send
                    when RDID_CMD => -- Read ID command
                         --tranf_state:=data;
                         tranf_state<=data;
                         wait for 1 fs;
                         tx_r <= MAN_DEV_ID(id_cnt);
                         wait for 1 fs;
                         if id_cnt=4 then
                            id_cnt:=0;
                         else
                            id_cnt:=id_cnt+1;
                         end if;
                    when READ_CMD | FREAD_CMD => -- Read or Fast Read byte command
                         case tranf_state is
                              when cmd =>      -- prepare data to send
                                   readfc(DATA_FILE, data_a);
                                   --tranf_state:=addr;
                                   tranf_state<=addr;
                                   wait for 1 fs;
                              when addr => -- get address and set data
                                   adr_r <= adr_r(15 downto 0) & rx_r;
                                   wait for 1 fs;
                                   if adr_cnt=2 then
                                      if cmd_r=FREAD_CMD then
                                         --tranf_state:=dummy;
                                         tranf_state<=dummy;
                                         wait for 1 fs;
                                      else
                                         --tranf_state:=data;
                                         tranf_state<=data;
                                         wait for 1 fs;
                                      end if;
                                      adr_os:=to_integer(unsigned(adr_r));
                                      tx_r <= data_a(adr_os);
                                      wait for 1 fs;
                                      adr_os:=adr_os+1;
                                   else
                                      adr_cnt:=adr_cnt+1;
                                   end if;
                              when dummy => -- Dummy byte for fast read
                                   --tranf_state:=data;
                                   tranf_state<=data;
                                   wait for 1 fs;
                              when data =>
                                   tx_r <= data_a(adr_os);
                                   wait for 1 fs;
                                   adr_os:=adr_os+1;
                              when others =>
                                   assert false report "Unknown state" severity failure;
                         end case;
                    when others =>  -- Unknown command
                         assert false report "Unknown command arrived ["&
                            hstr(cmd_r)&"]" severity failure;
               end case;
               if adr_os=data_a'length then -- At highest address, counter reverts to 0
                  adr_os:=0;
               end if;
            else
               bit_cnt:=bit_cnt+1;
            end if;
            so_o <= tx_r(7-bit_cnt);
        end loop;
      end loop;
      --report "******************************* CS";
      -- Wait for the next operation request
   end process proc_command;
end architecture Command; -- Entity: S25FL_sim


