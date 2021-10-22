# Modify this file to fit your own environment.
set company {NTUGIEE}
set designer {Student}

set search_path      ". /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/db  ./Memory/sram_1024x8_t13 $search_path"
set target_library   "slow.db                     \
					  typical.db
					  fast.db
                      sram_1024x8_t13_slow_syn.db \
                     "
set link_library     "* $target_library dw_foundation.sldb"
set symbol_library   "tsmc13.sdb generic.sdb"
set synthetic_library "dw_foundation.sldb"
set default_schematic_options {-size infinite}

set hdlin_translate_off_skip_text "TRUE"
set edifout_netlist_only "TRUE"
set verilogout_no_tri true

set hdlin_enable_presto_for_vhdl "TRUE"
set sh_enable_line_editing true
set sh_line_editing_mode emacs
history keep 100
alias h history

set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}



# operating conditions and boundary conditions #

set cycle  5.0      ;#clock period defined by designer

create_clock -period $cycle [get_ports  clk]
set_dont_touch_network      [get_clocks clk]
set_fix_hold                [get_clocks clk]
set_ideal_network           [get_ports clk]
set_clock_uncertainty  0.1  [get_clocks clk]
set_clock_latency      0.5  [get_clocks clk]
set_input_transition   0.5  [all_inputs]
set_clock_transition   0.1  [all_clocks]

set_input_delay  0.5    -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 0.5    -clock clk [all_outputs] 
set_load         0.1     [all_outputs]
set_drive        1     [all_inputs]

set_operating_conditions  -max slow  -min fast
set_wire_load_model -name tsmc13_wl10 -library slow                        

set_max_fanout 20 [all_inputs]