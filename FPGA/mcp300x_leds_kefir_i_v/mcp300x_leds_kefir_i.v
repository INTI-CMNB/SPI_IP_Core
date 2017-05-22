/***********************************************************************

  MCP3008 test for Kéfir I

  This file is part FPGA Libre project http://fpgalibre.sf.net/

  Description:
  Continually starts A/D convertions. Displays the 4 MSBs in the LEDs

  To Do:
  -

  Author:
    - Salvador E. Tropea, salvador en inti.gob.ar

------------------------------------------------------------------------------

 Copyright (c) 2016-2017 Salvador E. Tropea <salvador en inti.gob.ar>

 Distributed under the GPL v2 or newer license

------------------------------------------------------------------------------

 Design unit:      MCP300x_LEDs_Kefir_I(TopLevel) (Entity and arch.)
 File name:        mcp300x_leds_kefir_i.v
 Note:             None
 Limitations:      None known
 Errors:           None known
 Library:          None
 Dependencies:     IEEE.std_logic_1164
                   IEEE.numeric_std
 Target FPGA:      iCE40HX4K-TQ144
 Language:         Verilog
 Wishbone:         None
 Synthesis tools:  iCEcube2 2016.02
 Simulation tools: GHDL [Sokcho edition] (0.2x)
 Text editor:      SETEdit 0.5.x

***********************************************************************/

module MCP300x_LEDs_Kefir_I
   (
    input  CLK,
    output LED1, 
    output LED2, 
    output LED3, 
    output LED4, 
    output AD_CS, 
    output AD_Din, 
    input  AD_Dout,
    output AD_Clk, 
    output SS_B
   );

// The oscilator is 24 MHz, with 12 we get 1 MHz SPI clock. 55,6 ks/s
localparam DIVIDER=12;
localparam SHOW_MSBS=0;
reg  [3:0] cnt_div_spi=0;
wire       spi_ena;
wire       eoc;
wire [9:0] cur_val;
reg  [9:0] last_val_r=0;

assign SS_B=1; // Disable the SPI memory

//////////////////////
// SPI clock enable //
//////////////////////
always @(posedge CLK)
begin : do_spi_div
  if (cnt_div_spi==DIVIDER-1)
     cnt_div_spi=0;
  else
     cnt_div_spi=cnt_div_spi+1;
end // do_spi_div
assign spi_ena=cnt_div_spi==DIVIDER-1 ? 1 : 0;

///////////////////
// A/D interface //
///////////////////
MCP300x the_AD
  (// System
   .clk_i(CLK), .rst_i(0),
   // Master interface
   .start_i(1), .chn_i(0), .single_i(1),
   .ena_i(spi_ena), .eoc_o(eoc), .data_o(cur_val),
   // A/D interface
   .ad_ncs_o(AD_CS), .ad_clk_o(AD_Clk), .ad_din_o(AD_Din),
   .ad_dout_i(AD_Dout));

always @(posedge CLK)
begin : ad_val_reg
  if (eoc)
     last_val_r=cur_val;
end // ad_val_reg

///////////////////////////////////
// Show some bits using the LEDs //
///////////////////////////////////
generate
if (SHOW_MSBS)
   begin
   assign LED4=last_val_r[9];
   assign LED3=last_val_r[8];
   assign LED2=last_val_r[7];
   assign LED1=last_val_r[6];
   end // SHOW_MSBS
else
   begin
   assign LED4=last_val_r[3];
   assign LED3=last_val_r[2];
   assign LED2=last_val_r[1];
   assign LED1=last_val_r[0];
   end //!SHOW_MSBS
endgenerate

endmodule // MCP300x_LEDs_Kefir_I

