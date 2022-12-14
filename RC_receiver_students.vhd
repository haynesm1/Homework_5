-- RC_receiver
-- implement a data receiver for the DE2 remote control
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity RC_receiver is
generic (
	-- number of clocks for the leader code-on signal (assuming 50MHz clock)
	LC_on_max					: integer := 450000);
port (
	-- outputs to the 8 7-segement displays.  The remote control
	-- outputs 32 bits of binary data (each byte displayed as
	-- 2 7-segment displays)
	HEX7						: out std_logic_vector(6 downto 0);
	HEX6						: out std_logic_vector(6 downto 0);
	HEX5						: out std_logic_vector(6 downto 0);
	HEX4						: out std_logic_vector(6 downto 0);
	HEX3						: out std_logic_vector(6 downto 0);
	HEX2						: out std_logic_vector(6 downto 0);
	HEX1						: out std_logic_vector(6 downto 0);
	HEX0						: out std_logic_vector(6 downto 0);
	-- output to display when receiver is receiving data
	rd_data						: out std_logic;
	-- clock, data input, and system reset
	clk							: in std_logic;
	data_in						: in std_logic;
	reset						: in std_logic);
end RC_receiver;

architecture behavior of RC_receiver is
	
------------------------------------------------------------------------
-- leader code off duration
-- lengths of symbols '1' and '0'
-- length of transition time (padding)
constant LC_off_max				: integer := LC_on_max/2;
constant one_clocks				: integer := LC_on_max/4;
constant zero_clocks			: integer := LC_on_max/8;
constant padding				: integer := LC_on_max/50; -- 2% of max
------------------------------------------------------------------------
constant max_bits				: integer := 32;

-- counter for measuring the duration of the leader code-on signal
signal reading_LC_on			: std_logic := '0';
signal LC_on_counter			: integer range 0 to LC_on_max+padding;
-- counter for measuring the duration of the leader code-off signal
signal reading_LC_off			: std_logic := '0';
signal LC_off_counter			: integer range 0 to LC_off_max+padding;
-- counter for measuring the duration of the data signal
signal reading_data				: std_logic := '0';
signal clock_counter			: integer range 0 to one_clocks+padding;
signal checking_data			: std_logic := '0';
-- signal which determine the bit that is communicated
signal data_bit					: std_logic := '0';
-- counter to keep track of the number of bits transmitted
signal data_counter				: integer range 0 to max_bits-1;
-- signals for edge detection circuitry
signal data						: std_logic;
signal data_lead, data_follow 	: std_logic;
signal data_posedge				: std_logic;
-- shift register which holds the transmitted bits
signal shift_reg				: std_logic_vector(max_bits-1 downto 0) := (others => '0');

-- state machine signals
type state_type is(init, read_LC_on, check_LC_on_count, read_LC_off, 
	check_LC_off_count, read_data, check_data);
signal state, nxt_state			: state_type;
-- 7 segement display circuitry
component hex_to_7_seg is
port (seven_seg					: out std_logic_vector(6 downto 0);
		hex						: in std_logic_vector(3 downto 0));
end component;

begin	
	-- 7 seg displays receiver data
	seg_7: hex_to_7_seg port map(HEX7, shift_reg(max_bits-1 downto max_bits-4));
	seg_6: hex_to_7_seg port map(HEX6, shift_reg(max_bits-5 downto max_bits-8));
	seg_5: hex_to_7_seg port map(HEX5, shift_reg(max_bits-9 downto max_bits-12));
	seg_4: hex_to_7_seg port map(HEX4, shift_reg(max_bits-13 downto max_bits-16));
	seg_3: hex_to_7_seg port map(HEX3, shift_reg(max_bits-17 downto max_bits-20));
	seg_2: hex_to_7_seg port map(HEX2, shift_reg(max_bits-21 downto max_bits-24));
	seg_1: hex_to_7_seg port map(HEX1, shift_reg(max_bits-25 downto max_bits-28));
	seg_0: hex_to_7_seg port map(HEX0, shift_reg(max_bits-29 downto max_bits-32));

	-- data comes in inverted
	data <= not data_in;
	-- output the reading data signal
	rd_data <= reading_data;
	
	-- two process state machine
	--DONE AND SHOULD BE GOOD TO GO
	state_proc : process(clk) 
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				state <= init;
			else
				state <= nxt_state;
			end if;
		end if;
		-- the state machine should move to the "nxt_state" on the positive 
		-- edge of the clock
	end process state_proc;
		
	nxt_state_proc : process(state, LC_on_counter, LC_off_counter, clock_counter, 
		data_counter, data, data_posedge)
	begin
		nxt_state <= state;
		reading_LC_off <= '0';
		reading_LC_on <= '0';
		reading_data <= '0';
		checking_data <= '0';
		
		case state is
			when init =>
				if(data_posedge = '1') then
					nxt_state <= read_LC_on;
				end if;
			when read_LC_on =>
				reading_LC_on <= '1';
				if(data = '0') then
					nxt_state <= check_LC_on_count;
				else
					nxt_state <= read_LC_on;
				end if;
			when check_LC_on_count =>
			reading_data <= '1';
				if(LC_on_counter < LC_on_max+padding) then
					nxt_state <= read_LC_off;
				else
					--LC_on_counter <= 0;
					nxt_state <= init;
				end if;
			when read_LC_off =>
				reading_LC_off <= '1';
				reading_data <= '1';
				if(data_posedge = '1') then
					nxt_state <= check_LC_off_count;
				else
					nxt_state <= read_LC_off;
				end if;
			when check_LC_off_count =>
				reading_data <= '1';
				if(LC_off_counter < LC_off_max+padding) then
					nxt_state <= read_data;
				else
					nxt_state <= init;
				end if;
			when read_data =>
				reading_data <= '1';
				data_bit <= data_in;
				if(data_posedge = '1') then
					nxt_state <= check_data;
				else
					nxt_state <= read_data;
				end if;
			when check_data=>
				checking_data <= '1';
				reading_data <= '1';
				if(data_counter /= 31) then
					nxt_state <= read_data;
				else
					nxt_state <= init;
				end if;
			when others => nxt_state <= init;
		end case;
		-- define the state machine process here.  Use slide #6 on the assignment
		-- powerpoint as a guide.  This process should also set control signals:
		--	reading_LC_on
		--	reading_LC_off
		--	reading_data
		--	checking_data
		-- I also use this process to define signal:
		--	data_bit
	end process nxt_state_proc;
	
	-- process to detect positive edge
	data_posedge <= data_lead and (not data_follow);
	pos_edge_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				data_lead <= '0';
				data_follow <= '0';
			else	
				data_lead <= data_in;
				data_follow <= data_lead;
			end if;
		end if;
		-- use this process to determine the positive edge of the
		-- input data signal, data_in
	end process pos_edge_proc;
	-- counter for the leader code (ones)
	LC_on_proc : process(clk)
	begin
		if((rising_edge(clk))) then
			if((reset = '0') or (LC_on_counter = LC_on_max+padding)) then
				LC_on_counter <= 0;
			
			elsif(reading_LC_on = '1') then
				LC_on_counter <= LC_on_counter + 1;
			else	
				LC_on_counter <= 0;
			end if;
		end if;
		-- process to count the number of clocks during the LC_on
		-- portion of the incomming data sequence
	end process LC_on_proc;
	-- counter for the leader code (zeros)
	LC_off_proc : process(clk)
	begin
		if((rising_edge(clk))) then
			if((reset = '0') or (LC_off_counter = LC_off_max+padding)) then
				LC_off_counter <= 0;
			
			elsif(reading_LC_off = '1') then
				LC_off_counter <= LC_off_counter + 1;
			else	
				LC_off_counter <= 0;
			end if;
		end if;
		-- process to count the number of clocks during the LC_off
		-- portion of the incomming data sequence
	end process LC_off_proc;
	-- couner to count the number of clocks per data bit
	clock_counter_proc : process(clk)
	begin
		if((rising_edge(clk))) then
			if((reset = '0') or (clock_counter = one_clocks+padding)) then
				clock_counter <= 0;
			elsif(reading_data = '1') then
				clock_counter <= clock_counter + 1;
			else	
				clock_counter <= 0;
			end if;
		end if;
		-- process to count the number of clocks during the "data",
		-- or payload, portion of the data sequence
	end process clock_counter_proc;
	-- counter to counter the number of data bits
	data_counter_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if((reset = '0') or (data_counter = max_bits-1)) then
				data_counter <= 0;
			elsif(reading_data = '1') then
				data_counter <= data_counter +1;
			else 
				data_counter <= 0;
			end if;
		end if;
		--f((reading_data = '1') and (data_counter /= max_bits-1)) then
		--	data_counter <= data_counter +1;
		--nd if;
		--f(data_counter = max_bits - 1) then
		--	data_counter <= 0;
		--nd if;
		-- process to determine the number of data bits counted in the
		-- payload
	end process data_counter_proc;
	
	
	shift_reg_proc : process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				shift_reg <= (others => '0');
			elsif(reading_data = '1') then
				shift_reg <= shift_reg((max_bits-1) - 1 downto 0) & data;
			end if;
		end if;
		--if(reading_data ='1') then
		--	shift_reg <= shift_reg(max_bits-1 downto 1) & data_bit;
		--end if;
		-- process to define the shift register that holds the incomming
		-- data.  (hint:  don't use canned VHDL functions for shifting)
	end process shift_reg_proc;
end behavior;	
