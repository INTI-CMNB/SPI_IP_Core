/***********************************************************************

  MCP300x A/D controller (SPI master)

  This file is part FPGA Libre project http://fpgalibre.sf.net/

  Description:
  This core implements the communication with the MCP3004/8 A/D
  converter. This is basically a simple SPI.@p
  A new conversion is started when start_i is asserted, it must be
  kept high until busy_o becomes active.@p
  chn_i and single_i selects the channel and mode (see datasheet).@p
  The eoc_o signal indicates that a new value is available at data_o.
  This value must be read before a new conversion is started. The
  eoc_o signal lasts 1 clock.@p
  The SPI clock is determined by ena_i. This signal is enabled only
  during one clk_i cycle and it's frequency should be twice the
  desired SPI clock.@p

  To Do:
    -

  Author:
    - Salvador E. Tropea, salvador en inti.gob.ar

------------------------------------------------------------------------------

 Copyright (c) 2016 Salvador E. Tropea <salvador en inti.gob.ar>
 Copyright (c) 2016 Instituto Nacional de Tecnología Industrial

 Distributed under the GPL v2 or newer license

------------------------------------------------------------------------------

 Design unit:      MCP300x(RTL) (Entity and architecture)
 File name:        mcp300x.v
 Note:             None
 Limitations:      None known
 Errors:           None known
 Library:          None
 Dependencies:     IEEE.std_logic_1164
                   IEEE.numeric_std
 Target FPGA:      None
 Language:         Verilog
 Wishbone:         None
 Synthesis tools:  None
 Simulation tools: GHDL [Sokcho edition] (0.2x)
 Text editor:      SETEdit 0.5.x

***********************************************************************/

module MCP300x
  #(
    parameter FULL_RESET=1 // Reset affects all regs, even when not needed
   )
   (
    // System
    input        clk_i,    // System clock
    input        rst_i,    // System reset
    // Master interface
    input        start_i,  // Start conversion
    output       busy_o,   // Converting
    input  [2:0] chn_i,    // A/D channel
    input        single_i, // Single end (0 == diff.)
    input        ena_i,    // 2*SPI clk
    output       eoc_o,    // End of conversion
    output [9:0] data_o,   // Last A/D value
    // A/D interface
    output       ad_ncs_o, // SPI /CS
    output       ad_clk_o, // SPI clock
    output       ad_din_o, // SPI A/D Din (MOSI)
    input        ad_dout_i // SPI A/D Dout (MISO)
   );

localparam IDLE=0, TX=1, SAMPLE=2, RX=3, EOC=4; // state_t
reg  [2:0] state=IDLE;
reg  [9:0] data_r=0;
wire [4:0] data_tx;
reg  [3:0] cnt=0;
reg        ad_clk_r=0;

// 1  START
// Sn Single/not(Differential)
// D2 Channel bit 2
// D1 Channel bit 1
// D0 Channel bit 0
assign data_tx={1'b1,single_i,chn_i};

always @(posedge clk_i)
begin : do_FSM
  if (rst_i)
     begin
     state=IDLE;
     if (FULL_RESET)
        begin
        data_r=0;
        cnt=0;
        ad_clk_r=0;
        end
     end
  else
     begin
     // Generate the SPI clock all the time
     if (ena_i)
        ad_clk_r=!(ad_clk_r);
     case (state)
          IDLE:
             if (start_i && ena_i)
                begin
                state=TX;
                cnt=4;
                ad_clk_r=0;
                end
          TX:
             if (ena_i && ad_clk_r)
                begin
                if (cnt)
                   cnt=cnt-1;
                else
                   state=SAMPLE;
                end
          SAMPLE:
             if (ena_i && ad_clk_r)
                begin
                state=RX;
                cnt=11;
                end
          RX:
             if (ena_i)
                begin
                if (!ad_clk_r)
                   begin
                   data_r={data_r[8:0],ad_dout_i};
                   cnt=cnt-1;
                   end
                else
                   if (cnt==0)
                      state=EOC;
                end
          default: // EOC
             if (ena_i && ad_clk_r)
                begin
                if (start_i)
                   begin
                   state=TX;
                   cnt=4;
                   end
                else
                   state=IDLE;
                end
     endcase
     end
end // do_FSM

// Master interface
assign busy_o=state!=IDLE && state!=EOC ? 1 : 0; // Converting
assign eoc_o=state==EOC && ena_i ? 1 : 0; // End of conversion
assign data_o=data_r; // Last A/D value
// A/D interface
assign ad_ncs_o=state==IDLE || state==EOC ? 1 : 0;   // SPI /CS
assign ad_clk_o=ad_clk_r;   // SPI clock
assign ad_din_o=state==TX ? data_tx[cnt] : 0;  // SPI A/D Din (MOSI)

endmodule // MCP300x

