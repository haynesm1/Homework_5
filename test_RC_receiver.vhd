library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use std.textio.all ;
use ieee.std_logic_textio.all ;

use work.sim_mem_init.all;

entity test_RC_receiver is
end;

architecture test of test_RC_receiver is
  
component RC_receiver
generic (
	LC_on_max 					: integer := 450000);
port (	
	HEX7						: out std_logic_vector(6 downto 0);
	HEX6						: out std_logic_vector(6 downto 0);
	HEX5						: out std_logic_vector(6 downto 0);
	HEX4						: out std_logic_vector(6 downto 0);
	HEX3						: out std_logic_vector(6 downto 0);
	HEX2						: out std_logic_vector(6 downto 0);
	HEX1						: out std_logic_vector(6 downto 0);
	HEX0						: out std_logic_vector(6 downto 0);
		
	rd_data						: out std_logic;
			
	clk							: in std_logic;
	data_in						: in std_logic;
	reset						: in std_logic);
end component;

constant LC_on_max 				: integer := 50;

signal rd_data					: std_logic := '0';
signal clk						: std_logic := '0';
signal reset					: std_logic := '0';
signal data_in, n_data			: std_logic := '0';

constant num_segs 				: integer := 8;
constant seg_size 				: integer := 7;
type seg_arr is array(0 TO num_segs-1) of std_logic_vector(seg_size-1 downto 0);
signal seg, expected 			: seg_arr := ((others=> (others=>'0')));

constant in_fname 				: string := "NEC_input.csv";
constant out_fname 				: string := "NEC_output.csv";
file input_file,output_file 	: text;

begin
	n_data <= not data_in; -- data comes into the FPGA inverted
	dev_to_test:  RC_receiver 
		generic map(LC_on_max)
		port map(seg(7), seg(6), seg(5), seg(4), seg(3), seg(2), seg(1), seg(0),
				rd_data, clk, n_data, reset); 

	stimulus:  process
    variable input_line			: line;
	variable WriteBuf 			: line;
    variable in_char			: character;
	variable in_bit				: std_logic_vector(7 downto 0);
	variable out_slv			: std_logic_vector(7 downto 0);
    variable ErrCnt 			: integer := 0 ;
	variable read_rtn			: boolean;
	
	begin
		file_open(output_file, out_fname, read_mode);
		
		for k in 0 to num_segs-1 loop
			readline(output_file,input_line);
			for i in 0 to 1 loop
				read(input_line, in_char, read_rtn);
				out_slv := std_logic_vector(to_unsigned(character'pos(in_char),8));
				if(i = 0) then
					expected(k)(6 downto 4) <= ASCII_to_hex(out_slv)(2 downto 0);
				else
					expected(k)(3 downto 0) <= ASCII_to_hex(out_slv);
				end if;
			end loop;
		end loop;
		file_close(output_file);

		file_open(input_file, in_fname, read_mode);
		wait for 15 ns;
		reset <= '1';
		
		while not(endfile(input_file)) loop    
			-- read an input bit
			readline(input_file,input_line);
			while true loop
				read(input_line,in_char, read_rtn);
				if(read_rtn = false) then
					exit;
				end if;
				in_bit := std_logic_vector(to_unsigned(character'pos(in_char),8));
				if(in_bit /= x"30" and in_bit /= x"31") then
					exit;
				end if;
				data_in <= in_bit(0);
				clk <= '0';
				wait for 10 ns;			
				clk <= '1';
				wait for 10 ns;
			end loop;
		end loop;

		file_close(input_file);
		wait for 10 ns;
		
		for k in 0 to num_segs-1 loop
			if (expected(k) /= seg(k)) then
				write(WriteBuf, string'("ERROR:  7 seg display failed at k = "));
				write(WriteBuf, k);
				write(WriteBuf, string'("expected = "));
				write(WriteBuf, expected(k));
				write(WriteBuf, string'(", seg = "));
				write(WriteBuf, seg(k));
        
				writeline(Output, WriteBuf);
				ErrCnt := ErrCnt+1;
			end if; 
		end loop;
			
	    if (ErrCnt = 0) then 
			report "SUCCESS!!!  RC receiver Test Completed";
		else
			report "The RC receiver device is broken" severity warning;
		end if;
	end process;
end test;
