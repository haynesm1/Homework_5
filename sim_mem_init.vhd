-- sim_mem_init.vhd
-- package which allows for ModelSim simulation usint Quartus generated
-- memory initialization files
-- data_width must be 8 bits
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use std.textio.all ;
use ieee.std_logic_textio.all ;

package sim_mem_init is
	-- constant to print memory values to the console
	constant print_values 					: boolean := false;
	-- constants to define the size of the memory
	constant data_width 					: integer := 8;
	type MemType is array (natural range <>) of std_logic_vector(data_width-1 downto 0);
	-- function to convert ASCII text to a hex value
	function ASCII_to_hex(ASCII : in std_logic_vector(7 downto 0)) return std_logic_vector;
	-- function to initialize memory from a quartus generated .mif file
	impure function init_quartus_mem_8bit(mif_file_name : in string;
									constant mem_size : integer) return MemType;
end;

package body sim_mem_init is
	-- input is an ASCII character.  We assume the ASCII value is between 0 and F
	-- and therefore can be converted to a 4-bit HEX value
	function ASCII_to_hex(ASCII : in std_logic_vector(7 downto 0)) return std_logic_vector is
		variable hex 						: std_logic_vector(3 downto 0);

		begin
		case ASCII is
			when x"30" =>
				hex := x"0";
			when x"31" =>
				hex := x"1";
			when x"32" =>
				hex := x"2";
			when x"33" =>
				hex := x"3";
			when x"34" =>
				hex := x"4";
			when x"35" =>
				hex := x"5";
			when x"36" =>
				hex := x"6";
			when x"37" =>
				hex := x"7";
			when x"38" =>
				hex := x"8";
			when x"39" =>
				hex := x"9";
			when x"41" | x"61" =>
				hex := x"A";
			when x"42" | x"62" =>
				hex := x"B";
			when x"43" | x"63" =>
				hex := x"C";
			when x"44" | x"64" =>
				hex := x"D";
			when x"45" | x"65" =>
				hex := x"E";
			when x"46" | x"66" =>
				hex := x"F";
			when others =>
				hex := (others => 'X');
		end case;
					
		return hex;
	end function;
	-- memory initialization function reads a quartus generated .mif file
	impure function init_quartus_mem_8bit(mif_file_name : in string; 
									constant mem_size : integer) return MemType is
		-- file read variables
		file mif_file 						: text open read_mode is mif_file_name;
		variable mif_line 					: line;
		variable mif_char 					: character;
		variable success 					: boolean;
		
		-- we assume a memory size of less than 999999 entries
		constant indxWidth 					: integer := 6;
		type indxType is array (0 to indxWidth-1) of std_logic_vector(3 downto 0);
		variable indx 						: indxType;
		variable indx_max 					: integer := 0;
		
		-- we need 2 characters to be read at a time (to signify one byte)
		variable tempASCII 					: std_logic_vector(7 downto 0) := x"00";
		-- after conversion, the ASCII characters are translated into a hex value
		variable data						: unsigned(data_width-1 downto 0);
		variable slv2, slv1, slv0 			: std_logic_vector(3 downto 0) := x"0";
		variable dec2, dec1, dec0, total 	: integer;
		-- memory
		variable temp_mem 					: MemType(0 to mem_size);
		-- Write buffer for output to the command line
		variable WriteBuf 					: line ;
		
		variable i, loops 					: integer := 0;
		
		begin
					
		-- quartus has a 10000 loop limit, so we must include a counter
		while ((loops < 9999) and (not endfile(mif_file))) loop

			-- read a line of the .mif file
			readline(mif_file, mif_line);
			success := true;
			
			-- each new line, we reset the index values which
			-- indicate the address of each memory value
			for k in 0 to indxWidth-1 loop
				indx(k) := (others => '0');
			end loop;
			
			while success loop
				
				-- now we read individual characters of the .mif file
				read(mif_line, mif_char, success);
							
				-- jump over comments, or end of line indicator ';'
				if((mif_char = '-') or (mif_char = ';') or (not success)) then 
					exit;
					
				-- a bracket comes with a run of the same data values
				elsif(mif_char = '[') then
					mif_char := '0';
					-- reading the first index (we can just read over it, we do not use it)
					-- we are making sure we are reading decimal values from the .mif file
					-- indicating the memory address
					while((to_unsigned(character'pos(mif_char),8) < 58) and 
						(to_unsigned(character'pos(mif_char),8) > 47)) loop
						
						read(mif_line, mif_char, success);
					end loop;
					
					-- reading the ".." to the next index
					read(mif_line, mif_char, success);
					mif_char := '0';
					-- read the next index
					-- we are making sure we are reading decimal values from the .mif file
					-- indicating the memory address
					while((to_unsigned(character'pos(mif_char),8) < 58) and 
						(to_unsigned(character'pos(mif_char),8) > 47)) loop
						-- shift values to the left
						for k in indxWidth-1 downto 1 loop
							indx(k) := indx(k-1);
						end loop;
						-- convert the input ASCII value to a hex value
						indx(0) := ASCII_to_hex(std_logic_vector(to_unsigned((character'pos(mif_char)),8)));
												
						read(mif_line, mif_char, success);
					end loop;
					
					-- now we must convert the hex values to an integer
					indx_max := 0;
					for k in 0 to indxWidth-1 loop
						indx_max := indx_max + to_integer(unsigned(indx(k)))*(10**k);
					end loop;
												
					-- now we read find the colon which separates the address
					-- from the data value
					while((mif_char /= ':') and (success = true)) loop
						read(mif_line, mif_char, success);
					end loop;

					-- and we must first skip over spaces and tabs
					tempASCII := x"00";
					while((tempASCII = x"20") or (tempASCII = x"09") or (tempASCII = x"00")) loop
						read(mif_line, mif_char, success);
						tempASCII := std_logic_vector(to_unsigned(character'pos(mif_char),8));
					end loop;
					-- now we need to read the other data	
					slv2 := x"0";
					slv1 := x"0";
					slv0 := ASCII_to_hex(tempASCII);
					for k in 0 to 1 loop
						
						read(mif_line, mif_char, success);
						if(not success) then
							exit;
						end if;
						tempASCII := std_logic_vector(to_unsigned(character'pos(mif_char),8));
						-- if we read in a semi-colon, we are done
						if(tempASCII = x"3B") then
							exit;
						end if;
						-- shift data to the left
						slv2 := slv1;
						slv1 := slv0;
						slv0 := ASCII_to_hex(tempASCII);

					end loop;
					-- now we find the data value
					dec2 := to_integer(unsigned(slv2)*(x"64"));
					dec1 := to_integer(unsigned(slv1)*(x"A"));
					dec0 := to_integer(unsigned(slv0));
					total := dec2 + dec1 + dec0;
					data := to_unsigned(total, data'length);
					
					-- convert the ASCII characters to integers
					while(i <= indx_max) loop
						-- fill the memory
						temp_mem(i) := std_logic_vector(data);
						i := i + 1;
					end loop;								
					
				-- the data comes after the colon (non-repeating data values in the .mif file
				elsif(mif_char = ':') then --
									
					-- we must first skip over spaces and tabs
					tempASCII := x"00";
					while((tempASCII = x"20") or (tempASCII = x"09") or (tempASCII = x"00")) loop
						read(mif_line, mif_char, success);
						tempASCII := std_logic_vector(to_unsigned(character'pos(mif_char),8));
					end loop;
					slv2 := x"0";
					slv1 := x"0";
					slv0 := ASCII_to_hex(tempASCII);

					-- now we need to read the other data	
					for k in 0 to 1 loop
						
						read(mif_line, mif_char, success);
						if(not success) then
							exit;
						end if;
						tempASCII := std_logic_vector(to_unsigned(character'pos(mif_char),8));
						-- if we read in a semi-colon, we are done
						if(tempASCII = x"3B") then
							exit;
						end if;
						-- shift data to the left
						slv2 := slv1;
						slv1 := slv0;
						slv0 := ASCII_to_hex(tempASCII);

					end loop;
					-- now we convert the decimal data 
					dec2 := to_integer(unsigned(slv2)*(x"64"));
					dec1 := to_integer(unsigned(slv1)*(x"A"));
					dec0 := to_integer(unsigned(slv0));
					total := dec2 + dec1 + dec0;
					data := to_unsigned(total, data'length);
					-- fill the memory
					temp_mem(i) := std_logic_vector(data);
					
					i := i+1;
				end if;
			end loop;
			loops := loops + 1;
		end loop;
		-- print the memory values to std_out
		if(print_values = true) then
			for j in 0 to i-1 loop
				write(WriteBuf, string'("j = "));
				write(WriteBuf, j);
				write(WriteBuf, string'(".  "));
				write(WriteBuf, string'("temp_mem(j) = "));
				write(WriteBuf, temp_mem(j));
				writeline(Output, WriteBuf);
			end loop;
		end if;
		return temp_mem;
	end function;
end package body;