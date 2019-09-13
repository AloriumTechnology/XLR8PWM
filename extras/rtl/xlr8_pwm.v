/////////////////////////////////
// Filename    : xlr8_pwm.v
// Author      :
// Description : A configurable number of pwm channels...
//               AVR IO registers to access them.
//                4 Registers
//                  1) ControlRegister : bits
//                        [7]   = enable  channel (write - enables selected channel, read selected channel's enable state)
//                        [6]   = disable channel (write - disables selected channel, always read as zero)
//                        [5]   = update channel pulse width (write - transfers pulse width to channel, always read as zero)
//                        [4:0] = pwm channel to enable/disable/update
//                  2) PulseWidthL :  [3:0]= lower 4 bits of pwm pulse (high time) width in 1/16 microseconds
//                  3) PulseWidthH :  [7:0]= upper 8 bits of pwm pulse width in microseconds
//                       There is a PulseWidth register pair for each pwm channel. 
//                         When written, the channel to access is given in ControlReg[4:0].
//                       On write it sets the pulse width that will be set when the control
//                         register is written with the update bit set
//                       Read returns the last value written, regardless of ControlReg[4:0]
//                  4) PeriodL : [3:0] lower 4 bits of period in 1/16us increments
//                       The reset value = 0x0, which is approx
//                  5) PeriodH, high 8 bits of period in 
//                       The reset value = 0x7D, which with the low 4 bits is
//                       2000, resulting in 8kHz
//
//                   To start a channel
//                     - write the Period registers (or leave at default)
//                     - write the PulseWidth registers
//                     - write the control register with
//                       the desired channel to start,
//                       the enable, and update bits set
//
// Copyright 2015, Superion Technology Group. All Rights Reserved
/////////////////////////////////

module xlr8_pwm
 #(parameter NUM_PWMS = 12,
   parameter PWMCR_ADDR   = 6'h0, // pwm control register
   parameter PWMPWH_ADDR  = 6'h0, // pwm pulse width high
   parameter PWMPWL_ADDR  = 6'h0, // pwm pulse width low
   parameter PERIODL_ADDR = 6'h0, // pwm Period high
   parameter PERIODH_ADDR = 6'h0) // pwm Period low
  (input logic clk,
  input logic                   en16mhz, // clock enable at 16MHz rate
  input logic                   rstn,
  // Register access for registers in first 64
  input [5:0]                   adr,
  input [7:0]                   dbus_in,
  output [7:0]                  dbus_out,
  input                         iore,
  input                         iowe,
  output wire                   io_out_en,
  // Register access for registers not in first 64
  input wire [7:0]              ramadr,
  input wire                    ramre,
  input wire                    ramwe,
  input wire                    dm_sel,
  // External inputs/outputs
  output logic [NUM_PWMS-1:0] pwms_en, // Arduino Pin enable
  output logic [NUM_PWMS-1:0] pwms_out // Arduino Pin Value
  );

  /////////////////////////////////
  // Local Parameters
  /////////////////////////////////
  localparam NUM_TIMERS = (NUM_PWMS <= 16) ? NUM_PWMS : 16;
  // Registers in I/O address range x0-x3F (memory addresses -x20-0x5F)
  //  use the adr/iore/iowe inputs. Registers in the extended address
  //  range (memory address 0x60 and above) use ramadr/ramre/ramwe
  localparam  PWMCR_DM_LOC     = (PWMCR_ADDR   >= 16'h60) ? 1 : 0;
  localparam  PWMPWH_DM_LOC    = (PWMPWH_ADDR  >= 16'h60) ? 1 : 0;
  localparam  PWMPWL_DM_LOC    = (PWMPWL_ADDR  >= 16'h60) ? 1 : 0;
  localparam  PERIODH_DM_LOC   = (PERIODH_ADDR >= 16'h60) ? 1 : 0;
  localparam  PERIODL_DM_LOC   = (PERIODL_ADDR >= 16'h60) ? 1 : 0;

  // Control register bit definitions
  localparam PWMEN_BIT   = 7;
  localparam PWMDIS_BIT  = 6;
  localparam PWMUP_BIT   = 5;
  localparam PWMCHAN_LSB = 0;    

  /////////////////////////////////
  // Signals
  /////////////////////////////////
  /*AUTOREG*/
  /*AUTOWIRE*/ 
  // Address Decode Signals
  // Register address decode and read write signals
  logic pwmcr_sel;
  logic pwmpwh_sel;
  logic pwmpwl_sel;
  logic periodh_sel;
  logic periodl_sel;
  logic pwmcr_we ;
  logic pwmpwh_we ;
  logic pwmpwl_we ;
  logic periodh_we ;
  logic periodl_we ;
  logic pwmcr_re ;
  logic pwmpwh_re ;
  logic pwmpwl_re ;
  logic periodh_re ;
  logic periodl_re ;

  logic [7:0] pwmcr_rdata; // Control register read data
  logic       PWMEN;       // Selected channel enable state
  logic [4:0] PWMCHAN;     // Selected Channel
  logic [7:0] PWMPWH;      // Pulse Width Regiter Pair
  logic [7:0] PWMPWL;      //
  logic [7:0] PERIODH;     // Period Register Pair
  logic [7:0] PERIODL;     //
  logic [4:0] chan_in;     // Selected channel
  logic [15:0] chan_pw     [NUM_PWMS-1:0]; // pulse width per channel
  logic [15:0] global_period; // pulse width, this is global for the moment.  Not channel based
  logic [15:0] timercnt;

  /////////////////////////////////
  // Functions and Tasks
  /////////////////////////////////

  /////////////////////////////////
  // Main Code
  /////////////////////////////////
  //
  // PWM pulse with granualarity
  localparam PULSE_WIDTH_DIVIDE = 1024;
  //
  // Address Decoding Logic
  assign pwmcr_sel   = PWMCR_DM_LOC   ?  (dm_sel && ramadr == PWMCR_ADDR )   : (adr[5:0] == PWMCR_ADDR[5:0] ); 
  assign pwmpwh_sel  = PWMPWH_DM_LOC  ?  (dm_sel && ramadr == PWMPWH_ADDR )  : (adr[5:0] == PWMPWH_ADDR[5:0] );
  assign pwmpwl_sel  = PWMPWL_DM_LOC  ?  (dm_sel && ramadr == PWMPWL_ADDR )  : (adr[5:0] == PWMPWL_ADDR[5:0] );
  assign periodh_sel = PERIODH_DM_LOC ?  (dm_sel && ramadr == PERIODH_ADDR ) : (adr[5:0] == PERIODH_ADDR[5:0] );
  assign periodl_sel = PERIODL_DM_LOC ?  (dm_sel && ramadr == PERIODL_ADDR ) : (adr[5:0] == PERIODL_ADDR[5:0] );
  assign pwmcr_we    = pwmcr_sel   && (PWMCR_DM_LOC   ?  ramwe : iowe); 
  assign pwmpwh_we   = pwmpwh_sel  && (PWMPWH_DM_LOC  ?  ramwe : iowe);
  assign pwmpwl_we   = pwmpwl_sel  && (PWMPWL_DM_LOC  ?  ramwe : iowe); 
  assign periodh_we  = periodh_sel && (PERIODH_DM_LOC ?  ramwe : iowe);
  assign periodl_we  = periodl_sel && (PERIODL_DM_LOC ?  ramwe : iowe); 
  assign pwmcr_re    = pwmcr_sel   && (PWMCR_DM_LOC   ?  ramre : iore); 
  assign pwmpwh_re   = pwmpwh_sel  && (PWMPWH_DM_LOC  ?  ramre : iore);
  assign pwmpwl_re   = pwmpwl_sel  && (PWMPWL_DM_LOC  ?  ramre : iore); 
  assign periodh_re  = periodh_sel && (PERIODH_DM_LOC ?  ramre : iore);
  assign periodl_re  = periodl_sel && (PERIODL_DM_LOC ?  ramre : iore); 
  // Register Read Data MUX
  assign dbus_out =  ({8{pwmcr_sel}}   & pwmcr_rdata)   |
                     ({8{pwmpwh_sel}}  & PWMPWH)        | 
                     ({8{pwmpwl_sel}}  & PWMPWL)        | 
                     ({8{periodh_sel}} & PERIODH)       | 
                     ({8{periodl_sel}} & PERIODL); 
  // Register Read Data MUX enable for upper level hierarchy
  assign io_out_en = pwmcr_re   || 
                     pwmpwh_re  ||
                     pwmpwl_re  || 
                     periodh_re ||
                     periodl_re; 

   // Control Register Reset & Write by Host
  assign chan_in = dbus_in[PWMCHAN_LSB +: 5];

  // Control Register Enable & Channel write
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin  // Set Register to zero on reset
          PWMEN   <= 1'b0;
          PWMCHAN <= 5'h0;
          pwms_en <= {NUM_PWMS{1'b0}};
        end
      else if (pwmcr_we)
        begin  // Write the control register with enable and channel to access
          PWMCHAN<= chan_in;                 // Set the Channel to access
          PWMEN  <= dbus_in[PWMEN_BIT]  ||   // Set the Enable if written or if previously
                          (pwms_en[chan_in] && ~dbus_in[PWMDIS_BIT]); // Written
          pwms_en[chan_in] <= dbus_in[PWMEN_BIT] || 
                          (pwms_en[chan_in] && ~dbus_in[PWMDIS_BIT]);
        end
      else
        begin
          PWMEN <= pwms_en[PWMCHAN];  // When not writing register, get per channel eanble
        end
    end // always @ (posedge clk or negedge rstn)

  // Control register update bit
  // causes the Pulse Width and Period to be transfered to the operating registers
  always @(posedge clk)
    begin
      if (pwmcr_we)
        begin
          if (dbus_in[PWMUP_BIT])
            begin
              chan_pw[chan_in] <= {4'b0,PWMPWH ,PWMPWL[3:0]}; // Pulse width is a per channel setting
              global_period    <= {4'b0,PERIODH,PERIODL[3:0]};// Period is a system wide setting
            end
       end
    end // always @ (posedge clk or negedge rstn)

  // Control register read data
  assign pwmcr_rdata = ({7'h0,PWMEN}   << PWMEN_BIT) |  // Shift enable status into proper bit position
                       ({3'h0,PWMCHAN} << PWMCHAN_LSB); // Shift current channel into proper bit position

  // Period registers
  // Defaults to 125us (8kHz)
  // 4MSBs of the low period byte are unused
  //   This allows PERIODH to describe the period in 1 microsecond increments
  //   And PERIODL[3:0] to be a 1/16us fractional addition to the period
  //
  // The Period Width Register high byte write logic
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin
          PERIODH <= 8'h7D; // Default 8kHz 
        end
      else if (periodh_we)
        begin
          PERIODH  <= dbus_in;
        end 
    end

  // The Period Width Register low byte write logic lower 4 bits used
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin
          PERIODL <= 8'h0; // Default 8kHz
        end
      else if (periodl_we)
        begin
          PERIODL  <= dbus_in;
        end
    end

  // Pulse width registers
  // Defaults to 0
  // 4MSBs of the low puslewidth byte are unused
  //   This allows PWMPWH to describe the pulswidth in 1 microsecond increments
  //   And PWMPWL[3:0] to be a 1/16us fractional addition to the puslewidth
  //
  // The Pulse Width Register high byte write logic
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin
          PWMPWH <= 8'h0;
        end
      else if (pwmpwh_we)
        begin
          PWMPWH  <= dbus_in;
        end 
    end

  // The Pulse Width Register low byte write logic
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin
          PWMPWL <= 8'h0;
        end
      else if (pwmpwl_we)
        begin
          PWMPWL  <= dbus_in;
        end
    end

  // Run the counter at 16MHz for 0.0625us resolution
  always @(posedge clk or negedge rstn)
    begin
      if (!rstn)
        begin
          timercnt <= 16'h1;
        end
      else if (en16mhz && |pwms_en)  // If the counter is enabled, it counts
        begin
          // Period count.  When period reached, reset to 1
          timercnt <= (timercnt >= global_period) ? 16'd1 : (timercnt + 16'd1);
        end
    end // always @ (posedge clk or negedge rstn)

  // Output the PWM per channel
  genvar i;
  generate 
    for (i=0;i<NUM_PWMS;i++)
      begin : gen_chan
        always @(posedge clk or negedge rstn)
          begin
            if (!rstn)
              begin
                pwms_out[i] <= 1'b0;
              end
            else
              begin
                // Output is high until timercnt
                // reaches programmed chan_pw limit
                pwms_out[i] <= pwms_en[i] && (timercnt <= chan_pw[i]);
              end
          end // always @ (posedge clk or negedge rstn)
      end // block: gen_chan
  endgenerate
  
   /////////////////////////////////
   // Assertions
   /////////////////////////////////


   /////////////////////////////////
   // Cover Points
   /////////////////////////////////

endmodule

