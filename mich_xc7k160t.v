// Author:Salnikov
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module mich_xc7k160t
   #(
    parameter PIO_REGS                                          = 64,
    parameter PIO_RO_REGS                                       = 16,
    parameter HARDWARE_ID                                       = 64'hF000_0000_0000_00F1,
    parameter FIRMWARE_VER                                      = 64'h0000_0000_0000_0001,
    parameter UPLINKS                                           = 1,
    parameter DOWNLINKS                                         = 1,
    parameter TDATA_WIDTH                                       = 64,
    parameter TKEEP_WIDTH                                       = TDATA_WIDTH/8,
    parameter BUFFER_DEPTH                                      = 8,
    parameter USE_REGS                                          = 0,
    parameter PLINE_READY                                       = 1,
    parameter USE_INPIPE                                        = 3,
    parameter USE_OUTPIPE                                       = 3,
    parameter EMPTY_LATENCY                                     = 3,
    parameter MM_ADDR_WIDTH                                     = 8,
    parameter MM_DATA_WIDTH                                     = 64,
    parameter PACKET_LENGTH_WIDTH                               = 32,
	parameter PORTS_ADC											= 1,
	parameter PORTS_DAC											= 0,
	parameter ADC_DATA_WIDTH									= 8,
	parameter DAC_DATA_WIDTH									= 16,
    //adc
    parameter ADC_DAT_WIDTH                                     = 16,
    parameter PLL_SPI_PACKET_LENGTH                             = 32,
    parameter ADC_SPI_PACKET_LENGTH                             = 16
	
    )
    (
    // Interface: clk/reset
        input  wire                                                 gtrefclk_p,
        input  wire                                                 gtrefclk_n, 

//gt_serial_rx   
        input  wire rx_p,   
        input  wire rx_n,   
//gt_serial_rx   
        output wire tx_p,   
        output wire tx_n,   
  
/*        input  wire init_clk_p,   
        input  wire init_clk_n,*/
//aurora
        output wire SFP1_TX_DISAB,
        output wire SFP1_SCL_F,
        output wire SFP1_SDA_F,

// PLL_SPI
		output wire CDCE62005_D28_BUF_OE       	,
		output wire CDCE62005_D28_REF_SEL      	,
		output wire CDCE62005_D28_POWER_DOWN 	,
		output wire CDCE62005_D28_SPI_SYNC		,
		output wire CDCE62005_D28_SPI_CLK      	,
		output wire CDCE62005_D28_SPI_LE       	,
		output wire CDCE62005_D28_SPI_MOSI     	,
		input  wire 	CDCE62005_D28_SPI_MISO     	,
		input  wire 	CDCE62005_D28_PLL_LOCK     	,
		
		// ADC_SPI
		output wire ADC_SCK,	
		output wire ADC_CSA,	
		output wire ADC_CSB,	
		output wire ADC_SDI,	
		input  wire ADC_SDOA,
		input  wire ADC_SDOB,
		
		// ADC_DAT
		input  wire ADC_FRA_p,
		input  wire ADC_FRA_n,
		input  wire ADC_FRB_p,
		input  wire ADC_FRB_n,
		
		input  wire ADC_DCOA_p,
		input  wire ADC_DCOA_n,
		input  wire ADC_DCOB_p,
		input  wire ADC_DCOB_n,
		
		input  wire ADC_1A_p, input wire ADC_1A_n, input wire ADC_1B_p, input wire ADC_1B_n,
		input  wire ADC_2A_p, input wire ADC_2A_n, input wire ADC_2B_p, input wire ADC_2B_n,
		input  wire ADC_3A_p, input wire ADC_3A_n, input wire ADC_3B_p, input wire ADC_3B_n,
		input  wire ADC_4A_p, input wire ADC_4A_n, input wire ADC_4B_p, input wire ADC_4B_n,
		input  wire ADC_5A_p, input wire ADC_5A_n, input wire ADC_5B_p, input wire ADC_5B_n,
		input  wire ADC_6A_p, input wire ADC_6A_n, input wire ADC_6B_p, input wire ADC_6B_n,
		input  wire ADC_7A_p, input wire ADC_7A_n, input wire ADC_7B_p, input wire ADC_7B_n,
		input  wire ADC_8A_p, input wire ADC_8A_n, input wire ADC_8B_p, input wire ADC_8B_n,
		
		//BANK 16
		input  wire X192M2_p,
		input  wire X192M2_n,
		
		input  wire BUF3_100MHZ_p,
		input  wire BUF3_100MHZ_n


    );
wire gt_pll_lock;   
wire hard_err;
wire lane_up;
wire mmcm_not_locked_out;
wire soft_err;
wire tx_out_clk;
wire link_reset_out;
wire user_clk_out;
wire sync_clk_out;
wire init_clk_out;
wire sys_reset_out;  
  
  
    
   (* KEEP = "TRUE" *) wire [  UPLINKS-1:0]                                 status_up_channel_up;
   (* KEEP = "TRUE" *) wire pma_init;
    
   (* KEEP = "TRUE" *) wire clk_in;
   (* KEEP = "TRUE" *) wire sys_reset;
   (* KEEP = "TRUE" *) wire clk_out1;
   (* KEEP = "TRUE" *) wire clk_out2;
   (* KEEP = "TRUE" *) wire clk_out3;
   (* KEEP = "TRUE" *) wire mmcm_sys_locked;
    
    
    wire [  UPLINKS-1:0]                                 up_in_tready;
    wire [  UPLINKS-1:0]                                 up_in_tvalid;
    wire [  UPLINKS-1:0][TDATA_WIDTH-1:0]                up_in_tdata;
    wire [  UPLINKS-1:0]                                 up_in_tlast;
    wire [  UPLINKS-1:0][TKEEP_WIDTH-1:0]                up_in_tkeep;     
        
  (* KEEP = "TRUE" *) wire [  UPLINKS-1:0]                                 up_out_tready;
  (* KEEP = "TRUE" *) wire [  UPLINKS-1:0]                                 up_out_tvalid;
  (* KEEP = "TRUE" *) wire [  UPLINKS-1:0][TDATA_WIDTH-1:0]                up_out_tdata;
  (* KEEP = "TRUE" *) wire [  UPLINKS-1:0]                                 up_out_tlast;
  (* KEEP = "TRUE" *) wire [  UPLINKS-1:0][TKEEP_WIDTH-1:0]                up_out_tkeep;   
   wire status_timeout; 

 wire [UPLINKS*(DOWNLINKS+2)-1:0]                    			multi_up_out_tready	;
 wire [UPLINKS*(DOWNLINKS+2)-1:0]                    			multi_up_out_tvalid	;
 wire [UPLINKS*(DOWNLINKS+2)-1:0][TDATA_WIDTH-1:0]   			multi_up_out_tdata		;
 wire [UPLINKS*(DOWNLINKS+2)-1:0]                    			multi_up_out_tlast		;
 wire [UPLINKS*(DOWNLINKS+2)-1:0][TKEEP_WIDTH-1:0]   			multi_up_out_tkeep		;

  (* KEEP = "TRUE" *) wire [  UPLINKS-1:0]                                 up_in_tready_csr;
  (* KEEP = "TRUE" *)  wire [  UPLINKS-1:0]                                 up_in_tvalid_csr;
  (* KEEP = "TRUE" *)  wire [  UPLINKS-1:0][TDATA_WIDTH-1:0]                up_in_tdata_csr;
  (* KEEP = "TRUE" *)  wire [  UPLINKS-1:0]                                 up_in_tlast_csr;
  (* KEEP = "TRUE" *)  wire [  UPLINKS-1:0][TKEEP_WIDTH-1:0]                up_in_tkeep_csr;

   wire [  UPLINKS-1:0]                                 fifo_up_tx_tready;
   wire [  UPLINKS-1:0]                                 fifo_up_tx_tvalid;
   wire [  UPLINKS-1:0][TDATA_WIDTH-1:0]                fifo_up_tx_tdata;
   wire [  UPLINKS-1:0]                                 fifo_up_tx_tlast;
   wire [  UPLINKS-1:0][TKEEP_WIDTH-1:0]                fifo_up_tx_tkeep;   




(* TIG = "TRUE" *) wire 															global_reset					;
(* TIG = "TRUE" *) wire 															global_reset_n					;
//wire 																				s_clk_init						;
wire																				init_clk						;
(* TIG = "TRUE" *)	wire															init_clk_o						;

// mmcm wires
(* TIG = "TRUE" *)  wire															lock_mmcm						;	
(* KEEP = "TRUE" *)	wire															clk_drp							;

wire                                                                                csr_reset                       ;
wire                                                                                csr_clk                         ;

																

// AXI-Stream arbiter UP TX
(* KEEP = "FALSE" *) wire [UPLINKS-1:0][TDATA_WIDTH-1:0]                 			arbiter_up_tx_tdata				;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_tx_tvalid			;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0][TKEEP_WIDTH-1:0]                 			arbiter_up_tx_tkeep				;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_tx_tlast				;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_tx_tready			;

(* KEEP = "FALSE" *) wire [UPLINKS-1:0][TDATA_WIDTH-1:0]                 			arbiter_up_tx_tdata_aurora				;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_tx_tvalid_aurora			;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0][TKEEP_WIDTH-1:0]                 			arbiter_up_tx_tkeep_aurora				;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_tx_tlast_aurora				;
(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_tx_tready_aurora			;
wire [PACKET_LENGTH_WIDTH-1:0]                      								ctrl_arbiter_timeout			; 



(* KEEP = "FALSE" *) wire [UPLINKS-1:0]                                  			arbiter_up_status_timeout  		;

// Multichannel AXI-Stream arbiter UPLINK // +2 for CSR and test channel
(* KEEP = "FALSE" *) wire [UPLINKS*(DOWNLINKS+2)-1:0]                    			multi_axis_arbiter_up_tready	;
(* KEEP = "FALSE" *) wire [UPLINKS*(DOWNLINKS+2)-1:0]                    			multi_axis_arbiter_up_tvalid	;
(* KEEP = "FALSE" *) wire [UPLINKS*(DOWNLINKS+2)-1:0][TDATA_WIDTH-1:0]   			multi_axis_arbiter_up_tdata		;
(* KEEP = "FALSE" *) wire [UPLINKS*(DOWNLINKS+2)-1:0]                    			multi_axis_arbiter_up_tlast		;
(* KEEP = "FALSE" *) wire [UPLINKS*(DOWNLINKS+2)-1:0][TKEEP_WIDTH-1:0]   			multi_axis_arbiter_up_tkeep		;



//axis from axis_cnt to arbiter
(* KEEP = "FALSE" *) wire [TDATA_WIDTH-1:0]  										axis_up_cnt_tdata				;
(* KEEP = "FALSE" *) wire 															axis_up_cnt_tlast				;
(* KEEP = "FALSE" *) wire 															axis_up_cnt_tvalid				;
(* KEEP = "FALSE" *) wire [TKEEP_WIDTH-1:0]											axis_up_cnt_tkeep				;
(* KEEP = "FALSE" *) wire 															axis_up_cnt_tready				;
(* KEEP = "FALSE" *) wire                                     						axis_counter_ctrl_start			;
(* KEEP = "FALSE" *) wire [TDATA_WIDTH-1:0]                							axis_counter_ctrl_length		;	
(* KEEP = "FALSE" *) wire                                    						axis_counter_ctrl_ready			;


(* KEEP = "FALSE" *) wire                                    						axis_header_cnt_tready			;
(* KEEP = "FALSE" *) wire                                    						axis_header_cnt_tvalid			;
(* KEEP = "FALSE" *) wire [TDATA_WIDTH-1:0]                  						axis_header_cnt_tdata			;
(* KEEP = "FALSE" *) wire                                    						axis_header_cnt_tlast			;
(* KEEP = "FALSE" *) wire [TKEEP_WIDTH-1:0]                  						axis_header_cnt_tkeep			;	
(* KEEP = "FALSE" *) wire [TDATA_WIDTH-1:0]											s_header_word_cnt				;

// debug ports
wire 				 [3:0]															status_axis_rs_err				;
reg	 [PORTS_ADC-1:0]																rx_sync_adc_reg					;

wire global_reset1;
wire global_reset1_n;
wire global_reset_csr;
wire global_reset_100mhz;
wire 												axis_fr_extr_adc_ctrl_start; 		     
wire [TDATA_WIDTH-1:0]								axis_fr_extr_adc_ctrl_length;    	 
//wire [TDATA_WIDTH-1:0]								axis_fr_extr_adc_ctrl_cnt;
	(*keep="true"*)wire ini_clk_i;
	(*keep="true"*)wire pll_clk_spi;
	(*keep="true"*)wire mmcm_iclk_stop;
	(*keep="true"*)wire mmcm_lock;

                                      wire								m_spi_usr_dav;	                                
	                                  wire [ADC_SPI_PACKET_LENGTH-1:0]	m_spi_usr_dat;
    (*keep="true", mark_debug="true"*)wire								s_csr_rdy;
	(*keep="true", mark_debug="true"*)wire								s_csr_dav;//i_usr_control0[16];
	(*keep="true", mark_debug="true"*)wire [ADC_SPI_PACKET_LENGTH-1:0]	s_csr_dat;//i_usr_control0[15:0];

	(*keep="true", mark_debug="true"*)wire 								vio_gen_100_oe = 1'b1;			//1'b1;// разрешение работы генератора G_D27_ 100mhz
	(*keep="true", mark_debug="true"*)wire 								vio_pll_power_down_n1;   //1'b1;// сигнал аппаратного сброса pll
	(*keep="true", mark_debug="true"*)wire 								vio_pll_ref_sel = 1'b1;        //1'b0;// выбор порта источника опорного сигнала <PRI[1]/SEC[0]>
	(*keep="true", mark_debug="true"*)wire 								vio_pll_spi_sync_n1;     //1'b1;// сигнал синхронизации делитерей pll
	(*keep="true", mark_debug="true"*)wire 								vio_pll_lock;
	
	(*keep="true", mark_debug="true"*)wire								vio_pll_usr_s_rst1;
	(*keep="true", mark_debug="true"*)wire								vio_adc_usr_s_rst;
	
	(*keep="true", mark_debug="true"*)wire								vio_pll_usr_s_rdy;
	(*keep="true", mark_debug="true"*)wire								vio_pll_usr_s_dav1;
	(*keep="true", mark_debug="true"*)wire [PLL_SPI_PACKET_LENGTH-1:0]	vio_pll_usr_s_dat1;
	(*keep="true", mark_debug="true"*)wire								vio_pll_usr_m_dav;
	(*keep="true", mark_debug="true"*)wire [PLL_SPI_PACKET_LENGTH-1:0]	vio_pll_usr_m_dat;

// adc stream axi fragment extractor
(* KEEP = "TRUE" *) wire 															axis_fr_extr_adc_tvalid			;
(* KEEP = "TRUE" *) wire [(2*PORTS_ADC*TDATA_WIDTH-1):0] 							axis_fr_extr_adc_tdata			;
(* KEEP = "TRUE" *) wire 															axis_fr_extr_adc_tlast			;
(* KEEP = "TRUE" *) wire [(2*PORTS_ADC*TDATA_WIDTH/8-1):0]							axis_fr_extr_adc_tkeep			;
(* KEEP = "TRUE" *) wire                                                            axis_fr_extr_adc_tready         ;
 
 wire															                    axis_fr_extr_in_tvalid			; 														
(* KEEP = "TRUE" *) wire [2*TDATA_WIDTH-1:0]										axis_fr_extr_in_tdata			;
// ctrl axis_fragment_extractor		
(* KEEP = "TRUE" *) wire 															start_fr_extr_write_adc_data	;
(* KEEP = "TRUE" *) wire 															start_fr_extr_write_adc_data_resynch;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											length_adc_fr_ext_packet		;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											length_adc_fr_ext_packet_resync	;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											axis_fr_extr_adc_ctrl_cnt		;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											axis_fr_extr_adc_ctrl_cnt_resync;
(* KEEP = "TRUE" *) wire															axis_fr_extr_adc_ctrl_ready		;
(* KEEP = "TRUE" *) wire															axis_fr_extr_in_tready			;

// axis_width_adapter 
	//in ports
(* KEEP = "TRUE" *) wire    														m_axis_width_adapter_tvalid		;
(* KEEP = "TRUE" *) wire    														m_axis_width_adapter_tready    	;
(* KEEP = "TRUE" *) wire [(2*PORTS_ADC*TDATA_WIDTH-1):0]							m_axis_width_adapter_tdata		;
(* KEEP = "TRUE" *) wire [16-1/*(PORTS_ADC*TDATA_WIDTH/8-1)*/:0]    						m_axis_width_adapter_tkeep	    ;
(* KEEP = "TRUE" *) wire     														m_axis_width_adapter_tlast	    ;
	//out ports
(* KEEP = "TRUE" *) wire 															out_axis_adc_wa_tready			;			
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]	 										out_axis_adc_wa_tdata			;	
(* KEEP = "TRUE" *) wire 															out_axis_adc_wa_tvalid			;	
(* KEEP = "TRUE" *) wire 															out_axis_adc_wa_tlast			;	
(* KEEP = "TRUE" *) wire [TKEEP_WIDTH-1:0]											out_axis_adc_wa_tkeep			;

// axis_packet_chopper
(* KEEP = "TRUE" *) wire 															chopper_tready_adc_str			;		
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											chopper_tdata_adc_str			;
(* KEEP = "TRUE" *) wire 															chopper_tvalid_adc_str			;
(* KEEP = "TRUE" *) wire 															chopper_tlast_adc_str			;
(* KEEP = "TRUE" *) wire [TKEEP_WIDTH-1:0]											chopper_tkeep_adc_str			;

(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											s_axis_remote_wait_time_adc		;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											s_packet_length_adc				;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											s_packet_length_chopper_adc		;

// axis_remote source_insurer
(* KEEP = "TRUE" *) wire 															axis_adc_remote_tready			;			
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											axis_adc_remote_tdata			;		
(* KEEP = "TRUE" *) wire 															axis_adc_remote_tlast			;			
(* KEEP = "TRUE" *) wire 															axis_adc_remote_tvalid			;			
(* KEEP = "TRUE" *) wire [TKEEP_WIDTH-1:0]											axis_adc_remote_tkeep			;			

// header inserter adc stream
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]										  	s_axis_header_adc_stream		;

(* KEEP = "TRUE" *) wire 															out_axis_adc_header_ins_tready	;
(* KEEP = "TRUE" *) wire 															out_axis_adc_header_ins_tvalid	;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											out_axis_adc_header_ins_tdata	;	
(* KEEP = "TRUE" *) wire 															out_axis_adc_header_ins_tlast	;
(* KEEP = "TRUE" *) wire [TKEEP_WIDTH-1:0]											out_axis_adc_header_ins_tkeep	; 





clk_wiz_0 clk_wiz_0_inst (

    .clk_in1 (init_clk_o),
    .reset  (global_reset1),
    .clk_out100MHz (clk_out1),
    .clk_init_o192MHz (clk_out2),
    .clk_csr25MHz (csr_clk),
    .clk_pll_spi		(pll_clk_spi),
    .locked   (mmcm_sys_locked)
);



xilinx_reset_gen
#(
    .TIMEOUT       			(128							),
    .SYNC_LENGTH   			(6								)
)
xilix_reset_gen_after_power_up
(
    .clk					(init_clk_o						),
    .reset					(global_reset1					),
    .reset_n				(global_reset1_n					)	
);



xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_global_reset (

  .src_clk  				(init_clk_o 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(global_reset1				 ),							  
  .dest_clk 				(clk_out2							 ), 
  .dest_out 				(global_reset		 )
);

xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_rst_n_csr (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(ctrl_reset_ex_n				 ),							  
  .dest_clk 				(csr_clk							 ), 
  .dest_out 				(ctrl_reset_ex_n_csr		 )
);

wire ctrl_reset_ex;
wire ctrl_reset_ex_n;
wire ctrl_reset_ex_n_csr;

 
xilinx_reset_gen
#(
    .TIMEOUT       			(128							),
    .SYNC_LENGTH   			(6								)
)
xilix_reset_gen_extractor
(
    .clk					(clk_out1						),
    .reset					(ctrl_reset_ex					),
    .reset_n				(ctrl_reset_ex_n					)	
);

wire [13:0] axis_fifo_buf_wr_data_count ;
wire [13:0] axis_fifo_buf_rd_data_count ;
wire		axis_fifo_buf_axis_overflow ;
wire		axis_fifo_buf_axis_underflow;
wire status_up_channel_up1;
wire ctrl_soft_reset_request;
wire ctrl_soft_reset_request1;
wire ctrl_soft_reset; 
wire ctrl_soft_reset1; 
wire ctrl_aurora_reset_request;
//wire ctrl_aurora_reset_request1;
wire ctrl_aurora_reset;
wire ctrl_aurora_reset1;
wire pll_reset;


reset_ reset_aurora_inst (
    .clk(clk_out1),
    .enable(ctrl_aurora_reset_request),
    .reset(ctrl_aurora_reset1)
);

xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_ctrl_reset_aurora (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(ctrl_aurora_reset1				 ),							  
  .dest_clk 				(clk_out2							 ), 
  .dest_out 				(ctrl_aurora_reset		 )
);


 mich_xc7k160t_csr_wrapper
#(
	.PIO_REGS                                          	(PIO_REGS												),
	.PIO_RO_REGS                                       	(PIO_RO_REGS											),
	.HARDWARE_ID                                       	(HARDWARE_ID											),
	.FIRMWARE_VER                                      	(FIRMWARE_VER											),
	.UPLINKS                                           	(UPLINKS												),
	.DOWNLINKS                                         	(DOWNLINKS												),
	.TDATA_WIDTH                                       	(TDATA_WIDTH											),
	.TKEEP_WIDTH                                       	(TKEEP_WIDTH											),
	.BUFFER_DEPTH                                      	(BUFFER_DEPTH											),
	.USE_REGS                                          	(USE_REGS                  								),
	.PLINE_READY                                       	(PLINE_READY               								),
	.USE_INPIPE                                        	(USE_INPIPE                								),
	.USE_OUTPIPE                                       	(USE_OUTPIPE               								),
	.EMPTY_LATENCY                                     	(EMPTY_LATENCY            								),
	.MM_ADDR_WIDTH                                     	(MM_ADDR_WIDTH	          								),
	.MM_DATA_WIDTH                                     	(MM_DATA_WIDTH             								),
	.PACKET_LENGTH_WIDTH                               	(PACKET_LENGTH_WIDTH    								),
	.PORTS_ADC											(PORTS_ADC												),
	.PORTS_DAC											(PORTS_DAC												)
)
the_mich_xc7k160t_csr_wrp
(
// Interface: clk/reset
	.clk												(clk_out1        								),
	.reset_n											(/*global_reset_n*/ctrl_reset_ex_n 									),
	.csr_clk											(csr_clk                								),
	.csr_reset_n										(ctrl_reset_ex_n_csr  						),
// Interface: up_in
    .up_in_tready                           			(up_in_tready_csr										),
    .up_in_tvalid                           			(up_in_tvalid_csr										),								     	
    .up_in_tdata                            			(up_in_tdata_csr										),                                 	
    .up_in_tlast                            			(up_in_tlast_csr										),                                 	
    .up_in_tkeep                            			(up_in_tkeep_csr													),                                 	
// Interface: up_out
    .up_out_tready                          			(up_out_tready					       				),
    .up_out_tvalid                          			(up_out_tvalid					       				),
    .up_out_tdata                           			(up_out_tdata					       				),
    .up_out_tlast                           			(up_out_tlast					       				),
    .up_out_tkeep                           			(up_out_tkeep					       				),
// Arbiter timeout
	.ctrl_arbiter_timeout								(ctrl_arbiter_timeout									),

//// Link status
	.status_up_channel_up								(status_up_channel_up1						   		),
	
	.counter_ctrl_start									(axis_counter_ctrl_start								),
	.counter_ctrl_length								(axis_counter_ctrl_length								),
	.header_word_axis_test								(s_header_word_cnt										),			   
        
  .m_spi_usr_dat    (m_spi_usr_dat),      
  .m_spi_usr_dav    (m_spi_usr_dav),
  .s_csr_rdy        (s_csr_rdy),
  .s_csr_dat        (),
  .s_csr_dav        (),

  .pll_usr_m_dat    (vio_pll_usr_m_dat),   
  .pll_usr_m_dav    (vio_pll_usr_m_dav),
  .pll_lock         (vio_pll_lock),
  .pll_power_down_n (),
  .pll_spi_sync_n   (/*vio_pll_spi_sync_n1*/),
  .adc_usr_s_rst    (vio_adc_usr_s_rst),
  .pll_usr_s_dav    (vio_pll_usr_s_dav1),
  .pll_usr_s_dat    (vio_pll_usr_s_dat1),
  .pll_usr_s_rst    (pll_reset/*vio_pll_usr_s_rst1*/),

 //ctrl reset
  .ctrl_soft_reset_request(ctrl_soft_reset_request),
  .ctrl_aurora_reset_request(ctrl_aurora_reset_request),
//// axis fragment extractor adc data control/status
	.axis_fr_extr_adc_ctrl_start         				(start_fr_extr_write_adc_data							),	
    .axis_fr_extr_adc_ctrl_length        				(length_adc_fr_ext_packet								),	
    .axis_fr_extr_adc_ctrl_cnt           				(axis_fr_extr_adc_ctrl_cnt								),
	
//// axis header adc stream data
	.axis_header_adc_stream								(s_axis_header_adc_stream								),
	
//// axis_remote_wait_time_adc
	.axis_remote_wait_time_adc							(s_axis_remote_wait_time_adc							),

//// axis remote packet length
	.packet_length_adc									(s_packet_length_adc									),
	.packet_length_chopper_adc							(s_packet_length_chopper_adc							),

//// status pins	
	.status_axis_rs_err									(status_axis_rs_err										)
	
	
	
);


 auto_configuration_adc auto_configuration_adc_inst(
.clk          (clk_out1),            
.reset        (ctrl_reset_ex_n),          
.ctrl_soft    (pll_reset),     
.power_down_n (vio_pll_power_down_n1),   
.spi_sync_n   (vio_pll_spi_sync_n1),     
.usr_s_rst_pll(vio_pll_usr_s_rst1),  
.adc_s_dat    (s_csr_dat),      
.adc_s_dav    (s_csr_dav) 

 
 );
 
 
 ////////////////////////////////////////////////////////////////
// Test axis_counter data stream up
////////////////////////////////////////////////////////////////
axis_counter
		#(
		.TDATA_WIDTH        	(TDATA_WIDTH					),
		.TKEEP_WIDTH        	(TKEEP_WIDTH					),
		.BUFFER_DEPTH       	(BUFFER_DEPTH					),
		.LENGTH_WIDTH       	(TDATA_WIDTH					),
		.USE_REGS           	(USE_REGS						),
		.PLINE_READY        	(PLINE_READY					),
		.USE_INPIPE         	(USE_INPIPE						),
		.USE_OUTPIPE        	(USE_OUTPIPE					),
		.EMPTY_LATENCY      	(EMPTY_LATENCY					)
		)
    the_test_axis_counter
        (
        .reset_n            	(/*global_reset_n*/ctrl_reset_ex_n 			),
        .clk                	(clk_out1				),
        
        .out_tvalid         	(axis_up_cnt_tvalid				),
        .out_tready         	(axis_up_cnt_tready				),
        .out_tdata          	(axis_up_cnt_tdata				),
        .out_tlast          	(axis_up_cnt_tlast				),
        .out_tkeep          	(axis_up_cnt_tkeep				),

        .ctrl_up_down       	(1'b1							),
        .ctrl_start         	(axis_counter_ctrl_start		),
        .ctrl_stop          	(1'b0							),
        .ctrl_length        	(axis_counter_ctrl_length		),
        .ctrl_load          	(1'b0							),
        .ctrl_load_value    	({TDATA_WIDTH{1'b0}}			),
        .ctrl_ready_to_start	(                          		)
        );
		
////////////////////////////////////////////////////////////////
// axis_counter data stream up header inserter
////////////////////////////////////////////////////////////////
axis_header_inserter
        #(
        .TDATA_WIDTH        	(TDATA_WIDTH					),
        .TKEEP_WIDTH        	(TKEEP_WIDTH					),
        .BUFFER_DEPTH       	(BUFFER_DEPTH					),
        .USE_REGS           	(USE_REGS						),
        .PLINE_READY        	(PLINE_READY					),
        .USE_INPIPE         	(USE_INPIPE						),
        .USE_OUTPIPE        	(USE_OUTPIPE					),
        .EMPTY_LATENCY      	(EMPTY_LATENCY					),
        .HEADER_SIZE        	(1								)
        )
    the_test_axis_header_inserter
        (
        // System
        .clk                	(clk_out1				),
        .reset_n            	(/*global_reset_n*/ctrl_reset_ex_n 			),
        // Interface IN
        .in_tready          	(axis_up_cnt_tready				),
        .in_tvalid          	(axis_up_cnt_tvalid				),
        .in_tdata           	(axis_up_cnt_tdata				),
        .in_tlast           	(axis_up_cnt_tlast				),
        .in_tkeep           	(axis_up_cnt_tkeep				),
        // Interface INS
        .ins_tdata          	(s_header_word_cnt				),
        // Interface OUT
        .out_tready         	(axis_header_cnt_tready			),
        .out_tvalid         	(axis_header_cnt_tvalid			),
        .out_tdata          	(axis_header_cnt_tdata			),
        .out_tlast          	(axis_header_cnt_tlast			),
        .out_tkeep          	(axis_header_cnt_tkeep			)
        ); 
  

  
ila_3 ila_arbiter (
.clk(clk_out1),
.probe0(up_out_tdata),
.probe1(axis_header_cnt_tdata),
.probe2(out_axis_adc_header_ins_tdata),
.probe3(up_out_tkeep),
.probe4(axis_header_cnt_tkeep),
.probe5(out_axis_adc_header_ins_tkeep),
.probe6(multi_up_out_tvalid),
.probe7(multi_up_out_tlast),
.probe8(arbiter_up_tx_tready),
.probe9(multi_up_out_tready),
.probe10(arbiter_up_tx_tdata),
.probe11(arbiter_up_tx_tkeep),
.probe12(arbiter_up_tx_tvalid),
.probe13(arbiter_up_tx_tlast),
.probe14({adc_dat_dat1,adc_dat_dat2,adc_dat_dat3,adc_dat_dat4,
          adc_dat_dat5,adc_dat_dat6,adc_dat_dat7,adc_dat_dat8}),
.probe15(adc_dat_dav) 


);  
  
   
    
    
multi_axis_arbiter_with_timeout
        #(
        .ARBITERS               (UPLINKS	                    ),
        .PORTS                  (UPLINKS+2                       ), 
        .TDATA_WIDTH            (TDATA_WIDTH                    ),
        .TKEEP_WIDTH            (TKEEP_WIDTH                    ),
        .IN_BUF_SIZE            (2048			                ),
        .OUT_BUF_SIZE           (2048		                    ),
        .USE_REGS               (USE_REGS                       ),
        .PLINE_READY            (PLINE_READY                    ),
        .USE_INPIPE             (USE_INPIPE                     ),
        .USE_OUTPIPE            (USE_OUTPIPE                    ),
        .EMPTY_LATENCY          (EMPTY_LATENCY                  ),
        .TIMEOUT_WIDTH          (PACKET_LENGTH_WIDTH            )
        )
    axis_arbiter
        (
        .clk                    (clk_out1           ),
        .reset_n                (/*global_reset_n*/ctrl_reset_ex_n        ),

        .in_tready              (multi_up_out_tready 	),
        .in_tdata               (multi_up_out_tdata  	),
        .in_tvalid              (multi_up_out_tvalid 	),
        .in_tlast               (multi_up_out_tlast  	),
        .in_tkeep               (multi_up_out_tkeep  	),
        



        .out_tready             (arbiter_up_tx_tready	        ),
        .out_tdata              (arbiter_up_tx_tdata          	),
        .out_tvalid             (arbiter_up_tx_tvalid         	),
        .out_tlast              (arbiter_up_tx_tlast          	),
        .out_tkeep              (arbiter_up_tx_tkeep          	),

        .status_selected        (                               ),/*,
        .status_timeout         ( status_timeout	    ),
        .ctrl_timeout           (ctrl_timeout           )*/
        .ctrl_timeout           (ctrl_arbiter_timeout           )

        );

assign {
  out_axis_adc_header_ins_tready,axis_header_cnt_tready,up_out_tready 
} = multi_up_out_tready;

assign multi_up_out_tdata = {
  out_axis_adc_header_ins_tdata,axis_header_cnt_tdata,up_out_tdata
};

assign multi_up_out_tvalid = {
 out_axis_adc_header_ins_tvalid,axis_header_cnt_tvalid,up_out_tvalid
};

assign multi_up_out_tlast = {
    out_axis_adc_header_ins_tlast,axis_header_cnt_tlast,up_out_tlast
};
 
assign multi_up_out_tkeep = {
    out_axis_adc_header_ins_tkeep,axis_header_cnt_tkeep,up_out_tkeep	
};



//wire status_up_channel_up1;
xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_arbiter_valid (

  .src_clk  				(user_clk_out 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(status_up_channel_up				 ),							  
  .dest_clk 				(clk_out1							 ), 
  .dest_out 				(status_up_channel_up1		 )
);

wire status_up_channel_up_csr;

    aurora_dcfifo_wrp
            #(
            .TDATA_WIDTH            (TDATA_WIDTH                                    ),
            .TKEEP_WIDTH            (TKEEP_WIDTH                                    ),
            .PORTS                  (UPLINKS                                        ),
            .USE_CHIPSCOPE          (0                                              )
            )
        the_aurora_dcfifo_wrp
            (
            .sys_clk                (clk_out1),
            .sys_reset_n            (/*global_reset_n*/ctrl_reset_ex_n /*|| ctrl_soft_reset*/ ),
            .aurora_clk             (user_clk_out),

            .aurora_in_tvalid       (up_in_tvalid),
            .aurora_in_tdata        (up_in_tdata),
            .aurora_in_tlast        (up_in_tlast),
            .aurora_in_tkeep        (up_in_tkeep),
    
            .aurora_out_tready      (fifo_up_tx_tready),
            .aurora_out_tvalid      (fifo_up_tx_tvalid),
            .aurora_out_tdata       (fifo_up_tx_tdata),
            .aurora_out_tlast       (fifo_up_tx_tlast),
            .aurora_out_tkeep       (fifo_up_tx_tkeep),
    
            .sys_in_tready          (arbiter_up_tx_tready),
            .sys_in_tvalid          (arbiter_up_tx_tvalid),
            .sys_in_tdata           (arbiter_up_tx_tdata),
            .sys_in_tlast           (arbiter_up_tx_tlast),
            .sys_in_tkeep           (arbiter_up_tx_tkeep),
    
            .sys_out_tready         (up_in_tready_csr/*1'b1*/),
            .sys_out_tvalid         (up_in_tvalid_csr),
            .sys_out_tdata          (up_in_tdata_csr),
            .sys_out_tlast          (up_in_tlast_csr),
            .sys_out_tkeep          (up_in_tkeep_csr),

            .ctrl_pass              (1),
            .ctrl_channel_up        (status_up_channel_up1)
            );
top_lvl_aurora aurora_inst (

        // TX AXI4-S Interface
         .s_axi_tx_tdata(fifo_up_tx_tdata),
         .s_axi_tx_tlast(fifo_up_tx_tlast),
         .s_axi_tx_tkeep(fifo_up_tx_tkeep),
         .s_axi_tx_tvalid(fifo_up_tx_tvalid),
         .s_axi_tx_tready(fifo_up_tx_tready),


        // RX AXI4-S Interface
         .m_axi_rx_tdata(up_in_tdata),
         .m_axi_rx_tlast(up_in_tlast),
         .m_axi_rx_tkeep(up_in_tkeep),
         .m_axi_rx_tvalid(up_in_tvalid),



        // GT Serial I/O
         .rxp(rx_p),
         .rxn(rx_n),

         .txp(tx_p),
         .txn(tx_n),


        //GT Reference Clock Interface
        .gt_refclk1_p (gtrefclk_p),
        .gt_refclk1_n (gtrefclk_n),
        // Error Detection Interface
         .hard_err              (hard_err),
         .soft_err              (soft_err),

        // Status
         .channel_up            (status_up_channel_up),
         .lane_up               (lane_up),

        // System Interface
         .init_clk_out          (init_clk_out),
         .user_clk_out          (user_clk_out),

         .sync_clk_out(sync_clk_out),
         .reset_pb(global_reset || ~mmcm_sys_locked || ~ctrl_aurora_reset),
         .pma_init(~mmcm_sys_locked),
         .gt_pll_lock(gt_pll_lock),
         .drp_clk_in(clk_out1),// (drp_clk_i),
         .init_clk                              (clk_out2),
         .link_reset_out                        (link_reset_out),
         .mmcm_not_locked_out                   (mmcm_not_locked_out),




         .sys_reset_out                            (sys_reset_out),
         .tx_out_clk                               (tx_out_clk)

); 

	assign SFP1_TX_DISAB = 1'b1;
	assign SFP1_SCL_F = 1'b1;
	assign SFP1_SDA_F = 1'b1;







//-------------------------------------------------------------
	wire X192M2;
	
	IBUFDS #(
		.DIFF_TERM("FALSE"),       // Differential Termination
		.IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE" 
		.IOSTANDARD("DEFAULT")     // Specify the input I/O standard
	) IBUFDS_inst_1 (
		.O(init_clk_o),  // Buffer output
		.I(X192M2_p),  // Diff_p buffer input (connect directly to top-level port)
		.IB(X192M2_n) // Diff_n buffer input (connect directly to top-level port)
	);
	
	//-------------------------------------------------------------

	
	
    (*keep="true", mark_debug="true"*)wire 								vio_pll_power_down_n;   //1'b1;// сигнал аппаратного сброса pll
	(*keep="true", mark_debug="true"*)wire 								vio_pll_spi_sync_n;     //1'b1;// сигнал синхронизации делитерей pll
	(*keep="true", mark_debug="true"*)wire								vio_pll_usr_s_rst;
	(*keep="true", mark_debug="true"*)wire								vio_pll_usr_s_dav;
	(*keep="true", mark_debug="true"*)wire [PLL_SPI_PACKET_LENGTH-1:0]	vio_pll_usr_s_dat;
	(*keep="true", mark_debug="true"*)wire                             	global_reset_100mhz1;





	     //////csr
	                                  wire                              vio_pll_usr_m_dav1;

	ChipScope vio для pll*/
	xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_pll_m_dav (

  .src_clk  				(pll_clk_spi 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(vio_pll_usr_m_dav1				 ),							  
  .dest_clk 				(clk_out1							 ), 
  .dest_out 				(vio_pll_usr_m_dav		 )
);		
	xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_reset_pll (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(ctrl_reset_ex_n				 ),							  
  .dest_clk 				(pll_clk_spi							 ), 
  .dest_out 				(global_reset_100mhz1		 )
);
	xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_power_down (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(vio_pll_power_down_n1				 ),							  
  .dest_clk 				(pll_clk_spi							 ), 
  .dest_out 				(vio_pll_power_down_n		 )
);
xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_sync_n (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(vio_pll_spi_sync_n1				 ),							  
  .dest_clk 				(pll_clk_spi							 ), 
  .dest_out 				(vio_pll_spi_sync_n		 )
);
xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_pll_s_dav (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(vio_pll_usr_s_rst1				 ),							  
  .dest_clk 				(pll_clk_spi							 ), 
  .dest_out 				(vio_pll_usr_s_rst		 )
);
xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(32 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_pll_s_dat (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(vio_pll_usr_s_dat1				 ),							  
  .dest_clk 				(pll_clk_spi							 ), 
  .dest_out 				(vio_pll_usr_s_dat		 )
);
xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(1 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_pll_s_rst (

  .src_clk  				(clk_out1 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(vio_pll_usr_s_dav1				 ),							  
  .dest_clk 				(pll_clk_spi							 ), 
  .dest_out 				(vio_pll_usr_s_dav		 )
);
	
	
	
	

	/*
	Драйвер spi для настройки pll*/
	cdce62005_driver #(.WIDTH(PLL_SPI_PACKET_LENGTH)) cdce62005_driver_inst (
		.CDCE62005_D28_SPI_CLK      (CDCE62005_D28_SPI_CLK),
		.CDCE62005_D28_SPI_LE       (CDCE62005_D28_SPI_LE),
		.CDCE62005_D28_SPI_MOSI     (CDCE62005_D28_SPI_MOSI),
		.CDCE62005_D28_SPI_MISO     (CDCE62005_D28_SPI_MISO),
		.CDCE62005_D28_REF_SEL		(CDCE62005_D28_REF_SEL),
		.CDCE62005_D28_POWER_DOWN 	(CDCE62005_D28_POWER_DOWN),
		.CDCE62005_D28_SPI_SYNC		(CDCE62005_D28_SPI_SYNC),
		.CDCE62005_D28_PLL_LOCK     (CDCE62005_D28_PLL_LOCK),
		.CDCE62005_D28_BUF_OE       (CDCE62005_D28_BUF_OE),
		.i_usr_clk					(pll_clk_spi),
		.i_usr_rst					(~global_reset_100mhz1 || vio_pll_usr_s_rst),
		.i_usr_cfg_gen_oe			(vio_gen_100_oe),
		.i_usr_cfg_pll_power_down_n	(vio_pll_power_down_n),
		.i_usr_cfg_pll_ref_sel		(vio_pll_ref_sel),
		.i_usr_cfg_pll_sync_n		(vio_pll_spi_sync_n),
		.o_usr_cfg_pll_lock			(vio_pll_lock),
		.s_usr_rdy					(vio_pll_usr_s_rdy),
		.s_usr_dav					(vio_pll_usr_s_dav),
		.s_usr_dat					(vio_pll_usr_s_dat),//[WIDTH-1:0]	
		.m_usr_dav					(vio_pll_usr_m_dav1),
		.m_usr_dat					(vio_pll_usr_m_dat)//[WIDTH-1:0]	
	);	
	
	//-------------------------------------------------------------
	/*
	Драйвер для настройки и получения данных adc*/
	
	wire adc_dat_dav1;
	wire adc_dat_dav2;
	wire adc_dat_dav3;
	wire adc_dat_dav4;
	wire adc_dat_dav5;
	wire adc_dat_dav6;
	wire adc_dat_dav7;
	wire adc_dat_dav8;
	
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat1;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat2;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat3;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat4;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat5;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat6;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat7;
	wire [ADC_DAT_WIDTH-1:0] adc_dat_dat8;
	
	
	//-------------------------------------------------------------
	
	ltm9010_driver #(.FRAME_WIDTH(ADC_DAT_WIDTH),.USER_DATA_WIDTH(64)) ltm9010_driver_inst (
		// PHY
		.o_spi_sck		(ADC_SCK),
		.o_spi_cs_a		(ADC_CSA),
		.o_spi_cs_b		(ADC_CSB),
		.o_spi_sdi		(ADC_SDI),
		.i_spi_sdo_a	(ADC_SDOA),
		.i_spi_sdo_b	(ADC_SDOB),
		
		.i_phy_frm_a_p	(ADC_FRA_p),
		.i_phy_frm_a_n	(ADC_FRA_n),
		.i_phy_frm_b_p	(ADC_FRB_p),
		.i_phy_frm_b_n	(ADC_FRB_n),
		
		.i_phy_dco_a_p	(ADC_DCOA_p),
		.i_phy_dco_a_n	(ADC_DCOA_n),
		.i_phy_dco_b_p	(ADC_DCOB_p),
		.i_phy_dco_b_n	(ADC_DCOB_n),
		
		.i_phy_dat_a1_p	(ADC_1A_p),.i_phy_dat_a1_n	(ADC_1A_n),.i_phy_dat_b1_p	(ADC_1B_p),.i_phy_dat_b1_n	(ADC_1B_n),
		.i_phy_dat_a2_p	(ADC_2A_p),.i_phy_dat_a2_n	(ADC_2A_n),.i_phy_dat_b2_p	(ADC_2B_p),.i_phy_dat_b2_n	(ADC_2B_n),
		.i_phy_dat_a3_p	(ADC_3A_p),.i_phy_dat_a3_n	(ADC_3A_n),.i_phy_dat_b3_p	(ADC_3B_p),.i_phy_dat_b3_n	(ADC_3B_n),
		.i_phy_dat_a4_p	(ADC_4A_p),.i_phy_dat_a4_n	(ADC_4A_n),.i_phy_dat_b4_p	(ADC_4B_p),.i_phy_dat_b4_n	(ADC_4B_n),
		.i_phy_dat_a5_p	(ADC_5A_p),.i_phy_dat_a5_n	(ADC_5A_n),.i_phy_dat_b5_p	(ADC_5B_p),.i_phy_dat_b5_n	(ADC_5B_n),
		.i_phy_dat_a6_p	(ADC_6A_p),.i_phy_dat_a6_n	(ADC_6A_n),.i_phy_dat_b6_p	(ADC_6B_p),.i_phy_dat_b6_n	(ADC_6B_n),
		.i_phy_dat_a7_p	(ADC_7A_p),.i_phy_dat_a7_n	(ADC_7A_n),.i_phy_dat_b7_p	(ADC_7B_p),.i_phy_dat_b7_n	(ADC_7B_n),
		.i_phy_dat_a8_p	(ADC_8A_p),.i_phy_dat_a8_n	(ADC_8A_n),.i_phy_dat_b8_p	(ADC_8B_p),.i_phy_dat_b8_n	(ADC_8B_n),
		
		//csr
		.s_csr_rdy(s_csr_rdy),
		.m_spi_usr_dav(m_spi_usr_dav),
		.m_spi_usr_dat(m_spi_usr_dat),
		.s_csr_dav(s_csr_dav),
		.s_csr_dat(s_csr_dat),
		
		// USR
		.i_ini_clk_p	(BUF3_100MHZ_p),
		.i_ini_clk_n	(BUF3_100MHZ_n),
		.i_sys_clk		(clk_out1),
		.i_sys_rst		(~ctrl_reset_ex_n  || vio_adc_usr_s_rst),
		.i_usr_control0	(),	
		.o_usr_status0	(),	
		
		.o_dav_ch1		(adc_dat_dav1),
		.o_dav_ch2		(adc_dat_dav2),
		.o_dav_ch3		(adc_dat_dav3),
		.o_dav_ch4		(adc_dat_dav4),
		.o_dav_ch5		(adc_dat_dav5),
		.o_dav_ch6		(adc_dat_dav6),
		.o_dav_ch7		(adc_dat_dav7),
		.o_dav_ch8		(adc_dat_dav8),
		
		.o_dat_ch1		(adc_dat_dat1),//[FRAME_WIDTH-1:0]	
		.o_dat_ch2		(adc_dat_dat2),//[FRAME_WIDTH-1:0]	
		.o_dat_ch3		(adc_dat_dat3),//[FRAME_WIDTH-1:0]	
		.o_dat_ch4		(adc_dat_dat4),//[FRAME_WIDTH-1:0]	
		.o_dat_ch5		(adc_dat_dat5),//[FRAME_WIDTH-1:0]	
		.o_dat_ch6		(adc_dat_dat6),//[FRAME_WIDTH-1:0]	
		.o_dat_ch7		(adc_dat_dat7),//[FRAME_WIDTH-1:0]	
		.o_dat_ch8		(adc_dat_dat8)//[FRAME_WIDTH-1:0]	
	);
	
	//-------------------------------------------------------------
	
	//
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav1 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav1 <= adc_dat_dav1;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav2 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav2 <= adc_dat_dav2;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav3 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav3 <= adc_dat_dav3;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav4 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav4 <= adc_dat_dav4;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav5 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav5 <= adc_dat_dav5;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav6 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav6 <= adc_dat_dav6;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav7 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav7 <= adc_dat_dav7;
	(*keep="true", mark_debug="true", tig="true"*)	reg ila_adc_dat_dav8 = 1'b0; always @(posedge clk_out1) ila_adc_dat_dav8 <= adc_dat_dav8;
	
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat1 = 0; always @(posedge clk_out1) ila_adc_dat_dat1 <= adc_dat_dat1;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat2 = 0; always @(posedge clk_out1) ila_adc_dat_dat2 <= adc_dat_dat2;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat3 = 0; always @(posedge clk_out1) ila_adc_dat_dat3 <= adc_dat_dat3;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat4 = 0; always @(posedge clk_out1) ila_adc_dat_dat4 <= adc_dat_dat4;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat5 = 0; always @(posedge clk_out1) ila_adc_dat_dat5 <= adc_dat_dat5;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat6 = 0; always @(posedge clk_out1) ila_adc_dat_dat6 <= adc_dat_dat6;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat7 = 0; always @(posedge clk_out1) ila_adc_dat_dat7 <= adc_dat_dat7;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat8 = 0; always @(posedge clk_out1) ila_adc_dat_dat8 <= adc_dat_dat8;
	
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat1_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat1_sub <= adc_dat_dat1 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat2_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat2_sub <= adc_dat_dat2 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat3_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat3_sub <= adc_dat_dat3 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat4_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat4_sub <= adc_dat_dat4 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat5_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat5_sub <= adc_dat_dat5 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat6_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat6_sub <= adc_dat_dat6 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat7_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat7_sub <= adc_dat_dat7 - 8192;
	(*keep="true", mark_debug="true", tig="true"*)	reg [ADC_DAT_WIDTH-1:0]	ila_adc_dat_dat8_sub = 0; always @(posedge clk_out1) ila_adc_dat_dat8_sub <= adc_dat_dat8 - 8192;
    (*keep="true"*) wire adc_dat_dav_1;
    (*keep="true"*) wire adc_dat_dav;
    assign adc_dat_dav = adc_dat_dav1 && adc_dat_dav2 && adc_dat_dav3 && adc_dat_dav4 && adc_dat_dav5 && adc_dat_dav6 && adc_dat_dav7 && adc_dat_dav8 ;


xpm_cdc_array_single #(

  //Common module parameters
  .DEST_SYNC_FF   			(6										), // integer; range: 2-10
  .SIM_ASSERT_CHK 			(0										), // integer; 0=disable simulation messages, 1=enable simulation messages
  .SRC_INPUT_REG  			(1										), // integer; 0=do not register input, 1=register input
  .WIDTH          			(64 									)  // integer; range: 2-1024

) xpm_cdc_array_single_inst_axis_fragment_extractor2csr (

  .src_clk  				(clk_out1	 					     ),  // optional; required when SRC_INPUT_REG = 1
  .src_in   				(axis_fr_extr_adc_ctrl_cnt_resync		 ),							  
  .dest_clk 				(clk_out1						 ), 
  .dest_out 				(axis_fr_extr_adc_ctrl_cnt				 )
);	
wire [127:0]fifo_extr_tdata;
wire fifo_extr_tvalid;
wire fifo_extr_tready;


axis_fragment_extractor 

    #(
	.TDATA_WIDTH         	(64*2							),												
	.TKEEP_WIDTH         	(64*2/8							),												
	.LENGTH_WIDTH        	(64									) 	 												
    )
the_adc_axis_fragment_extractor        
    (
    // Interface: clk
        .clk                (clk_out1						),	//: in  std_logic;
    // Interface: reset      
        .reset_n            (ctrl_reset_ex_n 							),	//: in  std_logic;
    // Interface: AXI-Stream input
        .in_tvalid          (adc_dat_dav				),	//: in   std_logic;
        .in_tready          (			),	//: out  std_logic;
        .in_tdata           ({adc_dat_dat1,adc_dat_dat2,adc_dat_dat3,adc_dat_dat4,
                          adc_dat_dat5,adc_dat_dat6,adc_dat_dat7,adc_dat_dat8}				),	//: in   std_logic_vector(511 downto 0); 
    // Interface: AXI-Stream output
        .out_tvalid         (axis_fr_extr_adc_tvalid			),	//: out  std_logic;
        .out_tready         (axis_fr_extr_adc_tready			),	//: in   std_logic;
        .out_tdata          (axis_fr_extr_adc_tdata				),	//: out  std_logic_vector(511 downto 0);
        .out_tlast          (axis_fr_extr_adc_tlast				),	//: out  std_logic;
        .out_tkeep          (axis_fr_extr_adc_tkeep				),	//: out  std_logic_vector(63 downto 0);
    // Interface: control
		.ctrl_start         (start_fr_extr_write_adc_data),	//: in   std_logic;
        .ctrl_stop          (1'b0								),	//: in   std_logic;
        .ctrl_length        (length_adc_fr_ext_packet	),	//: in   std_logic_vector(63 downto 0);
        .ctrl_cnt           (axis_fr_extr_adc_ctrl_cnt_resync	),	//: out  std_logic_vector(63 downto 0);
        .ctrl_ready_to_start(axis_fr_extr_adc_ctrl_ready		)	//: out  std_logic
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//________________________The_adc_axis_buffer_to_axis_width_adapter_______________________________________________________//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
wire [13:0] axis_fifo_buf_wr_data_count ;
wire [13:0] axis_fifo_buf_rd_data_count ;
wire		axis_fifo_buf_axis_overflow ;
wire		axis_fifo_buf_axis_underflow;

fifo_buffer_for_adc_stream
the_fifo_buffer_for_adc_stream  
  (
    .s_aclk 				(clk_out1						),	//: IN STD_LOGIC;
    .s_aresetn 				(ctrl_reset_ex_n 							),	//: IN STD_LOGIC;
    .s_axis_tvalid 			(axis_fr_extr_adc_tvalid			),	//: IN STD_LOGIC;
    .s_axis_tready 			(axis_fr_extr_adc_tready			),	//: OUT STD_LOGIC;
    .s_axis_tdata 			(axis_fr_extr_adc_tdata				),	//: IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    .s_axis_tkeep 			(axis_fr_extr_adc_tkeep				),	//: IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    .s_axis_tlast 			(axis_fr_extr_adc_tlast				),	//: IN STD_LOGIC;
    .m_axis_tvalid 			(m_axis_width_adapter_tvalid		),	//: OUT STD_LOGIC;
    .m_axis_tready 			(m_axis_width_adapter_tready		),	//: IN STD_LOGIC;
    .m_axis_tdata 			(m_axis_width_adapter_tdata			),	//: OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
    .m_axis_tkeep 			(m_axis_width_adapter_tkeep			),	//: OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    .m_axis_tlast 			(m_axis_width_adapter_tlast			) 	//: OUT STD_LOGIC

  );
  
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//________________________The_adc_axis_width_adapter_to_axis_chip2chip____________________________________________________//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
axis_width_adapter
    #(
    .IN_TDATA_WIDTH    		(64*2/**2*4*/								),
    .OUT_TDATA_WIDTH   		(TDATA_WIDTH						),
    .IN_TKEEP_WIDTH    		(64*2/**2*4*//8							),
    .OUT_TKEEP_WIDTH   		(TDATA_WIDTH/8						),
    .IN_BUF_SIZE       		(1024								),
    .OUT_BUF_SIZE      		(1024								),
    .USE_REGS          		(USE_REGS							),
    .PLINE_READY       		(PLINE_READY						),
    .USE_INPIPE        		(USE_INPIPE							),
    .USE_OUTPIPE       		(USE_OUTPIPE						),
    .EMPTY_LATENCY     		(EMPTY_LATENCY						)
    )
	the_adc_stream_axis_width_adapter
    (
    // Interface: clk/reset
    .clk					(clk_out1					),
    .reset_n				(/*global_reset_n*/ctrl_reset_ex_n 				),
    // Interface: in
    .in_tready				(m_axis_width_adapter_tready	),
    .in_tdata				(m_axis_width_adapter_tdata			),
    .in_tvalid				(m_axis_width_adapter_tvalid	),
    .in_tlast				(m_axis_width_adapter_tlast			),
    .in_tkeep				(m_axis_width_adapter_tkeep		),
    // Interface: out
    .out_tready				(out_axis_adc_wa_tready				),
    .out_tdata				(out_axis_adc_wa_tdata				),
    .out_tvalid				(out_axis_adc_wa_tvalid				),
    .out_tlast				(out_axis_adc_wa_tlast				),
    .out_tkeep              (out_axis_adc_wa_tkeep				)
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//________________________The_adc_axis_packet_chopper_____________________________________________________________________//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		

axis_packet_chopper
    #(
    .PACKET_LENGTH_WIDTH   (TDATA_WIDTH							),
    .TDATA_WIDTH           (TDATA_WIDTH							),
    .TKEEP_WIDTH           (TKEEP_WIDTH							),
    .IBUFFER_DEPTH         (1024								),
    .OBUFFER_DEPTH         (1024								),
    .USE_REGS              (USE_REGS							),
    .PLINE_READY           (PLINE_READY							),
    .USE_INPIPE            (USE_INPIPE							),
    .USE_OUTPIPE           (USE_OUTPIPE							),
    .EMPTY_LATENCY         (EMPTY_LATENCY						)
    )
    axis_packet_chopper_adc_stream
    (
    // Interface: clk/reset
    .clk                   (clk_out1					),
    .reset_n               (ctrl_reset_ex_n 					),
    // Interface: in
    .in_tready             (out_axis_adc_wa_tready				),
    .in_tvalid             (out_axis_adc_wa_tvalid				),
    .in_tdata              (out_axis_adc_wa_tdata				),
    .in_tlast              (out_axis_adc_wa_tlast				),
    .in_tkeep              (out_axis_adc_wa_tkeep				),
    
    // Interface: out
    .out_tready            (chopper_tready_adc_str				),
    .out_tvalid            (chopper_tvalid_adc_str				),
    .out_tdata             (chopper_tdata_adc_str				),
    .out_tlast             (chopper_tlast_adc_str				),
    .out_tkeep             (chopper_tkeep_adc_str				),
    
    // Interface: control
    .ctrl_enable           (1'b1								),
    .ctrl_packet_length    (s_packet_length_chopper_adc			),
    
    // Interface: status
    .status_packet_cnt     (									)
    );


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//________________________The_adc_axis_sync_source_remote_________________________________________________________________//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		
axis_remote_sources_sync
#(
	.TDATA_WIDTH            				(TDATA_WIDTH						),
	.TKEEP_WIDTH            				(TKEEP_WIDTH						),
	.PORTS                  				(1									),
	.PACKET_LENGTH_WIDTH    				(TDATA_WIDTH						),
	.FRAME_LENGTH_WIDTH     				(TDATA_WIDTH						),
	.WAIT_TIME_WIDTH        				(TDATA_WIDTH						),
	.IN_BUFFER_DEPTH        				(1024								),
	.OUT_BUFFER_DEPTH       				(1024								),
	.USE_REGS               				(USE_REGS							),
	.PLINE_READY            				(PLINE_READY						),
	.USE_INPIPE             				(USE_INPIPE							),
	.USE_OUTPIPE            				(USE_OUTPIPE						),
	.EMPTY_LATENCY          				(EMPTY_LATENCY						)
)
axis_remote_source_sync_adc_stream
(
	.clk                                    (clk_out1					),
	.reset_n                                (/*global_reset_n*/ctrl_reset_ex_n 				),
	
	.control_source_active                  (1'b1								),
	.control_packet_length                  (s_packet_length_adc-1				),
	.control_frame_length                   (64'd1								),
	.control_source_wait_time               (s_axis_remote_wait_time_adc		),

	.number_counter_sload_packet            (1'b0),
	//.number_counter_sload_packet_data       ({}),
	.number_counter_sload_frame             (1'b0),
	//.number_counter_sload_frame_data        (),
	
	// outputs
	.status_frame_number                    (									),
	.status_packet_number                   (									),
	.status_new_packet_dav                  (									),
	.status_working                         (									),
	.status_time_left                       (									),
	.status_eat                             (									),
	.status_add                             (									),
	
	.error_too_long                         (status_axis_rs_err		[0]			),
	.error_too_short                        (status_axis_rs_err		[1]			),
	.error_mid_timeout                      (status_axis_rs_err		[2]			),
	.error_no_packet_timeout                (status_axis_rs_err		[3]			),
	
	// axis
	.in_tready                              (chopper_tready_adc_str				),
	.in_tvalid                              (chopper_tvalid_adc_str				),
	.in_tlast                               (chopper_tlast_adc_str				),
	.in_tdata                               (chopper_tdata_adc_str				),
	
	.out_tready                             (axis_adc_remote_tready				),
	.out_tvalid                             (axis_adc_remote_tvalid				),
	.out_tlast                              (axis_adc_remote_tlast				),
	.out_tdata                              (axis_adc_remote_tdata				)
);                                            				
	
assign axis_adc_remote_tkeep = {TKEEP_WIDTH{1'b1}};	
	
	
	////////////////////////////////////////////////////////////////
// axis_counter data stream up header inserter
////////////////////////////////////////////////////////////////


axis_header_inserter
        #(
        .TDATA_WIDTH        	(TDATA_WIDTH					),
        .TKEEP_WIDTH        	(TKEEP_WIDTH					),
        .BUFFER_DEPTH       	(1024							),
        .USE_REGS           	(USE_REGS						),
        .PLINE_READY        	(PLINE_READY					),
        .USE_INPIPE         	(USE_INPIPE						),
        .USE_OUTPIPE        	(USE_OUTPIPE					),
        .EMPTY_LATENCY      	(EMPTY_LATENCY					),
        .HEADER_SIZE        	(1								)
        )
    the_adc_stream_axis_header_inserter
        (
        // System
        .clk                	(clk_out1				),
        .reset_n            	(ctrl_reset_ex_n			),
        // Interface IN
        .in_tready          	(axis_adc_remote_tready			),
        .in_tvalid          	(axis_adc_remote_tvalid			),
        .in_tdata           	(axis_adc_remote_tdata			),
        .in_tlast           	(axis_adc_remote_tlast			),
        .in_tkeep           	(axis_adc_remote_tkeep			),
        // Interface INS
        .ins_tdata          	(s_axis_header_adc_stream		),
        // Interface OUT
        .out_tready         	(out_axis_adc_header_ins_tready1	),
        .out_tvalid         	(out_axis_adc_header_ins_tvalid1	),
        .out_tdata          	(out_axis_adc_header_ins_tdata1	),
        .out_tlast          	(out_axis_adc_header_ins_tlast1	),
        .out_tkeep          	(out_axis_adc_header_ins_tkeep1)
        );

(* KEEP = "TRUE" *) wire 															out_axis_adc_header_ins_tready1	;
(* KEEP = "TRUE" *) wire 															out_axis_adc_header_ins_tvalid1	;
(* KEEP = "TRUE" *) wire [TDATA_WIDTH-1:0]											out_axis_adc_header_ins_tdata1	;	
(* KEEP = "TRUE" *) wire 															out_axis_adc_header_ins_tlast1	;
(* KEEP = "TRUE" *) wire [TKEEP_WIDTH-1:0]											out_axis_adc_header_ins_tkeep1	; 





endmodule
