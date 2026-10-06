library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_hft_cms_top_final is
end tb_hft_cms_top_final;

architecture sim of tb_hft_cms_top_final is

    component hft_cms_top
        port (
            clk            : in  std_logic;
            rst            : in  std_logic;
            key_in         : in  std_logic_vector(31 downto 0);
            activity_in    : in  std_logic_vector(31 downto 0);
            valid_in       : in  std_logic;
            threshold      : in  std_logic_vector(31 downto 0);
            read_addr      : in  std_logic_vector(3 downto 0);
            read_key_out   : out std_logic_vector(31 downto 0);
            read_count_out : out std_logic_vector(31 downto 0)
        );
    end component;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal key_in      : std_logic_vector(31 downto 0) := (others => '0');
    signal activity_in : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_in    : std_logic := '0';
    
    -- Hardcoded to your 20,000 threshold (Decimal 20000 = Hex 00004E20)
    signal threshold   : std_logic_vector(31 downto 0) := x"00004E20"; 
    
    signal read_addr      : std_logic_vector(3 downto 0) := (others => '0');
    signal read_key_out   : std_logic_vector(31 downto 0);
    signal read_count_out : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    -- Define files for reading and writing
    file input_file  : text open read_mode is "market_stream.txt";
    file output_file : text open write_mode is "hardware_heavy_hitters.txt";

begin

    uut: hft_cms_top
        port map (
            clk            => clk,
            rst            => rst,
            key_in         => key_in,
            activity_in    => activity_in,
            valid_in       => valid_in,
            threshold      => threshold,
            read_addr      => read_addr,
            read_key_out   => read_key_out,
            read_count_out => read_count_out
        );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
        variable v_iline   : line;
        variable v_oline   : line;
        variable v_key_hex : std_logic_vector(31 downto 0);
        variable v_vol_hex : std_logic_vector(31 downto 0);
        variable v_space   : character;
    begin
        -- 1. Initialize and Reset
        rst <= '1';
        wait for CLK_PERIOD * 10;
        rst <= '0';
        wait for CLK_PERIOD * 10;

        report "Starting ITCH data injection...";
        
        -- 2. Read input file and push to pipeline
        while not endfile(input_file) loop
            readline(input_file, v_iline);
            
            -- Parse the two hex values separated by a space
            hread(v_iline, v_key_hex);
            read(v_iline, v_space); 
            hread(v_iline, v_vol_hex);

            key_in      <= v_key_hex;
            activity_in <= v_vol_hex;
            valid_in    <= '1';
            
            wait for CLK_PERIOD;
        end loop;
        
        -- Stop feeding data
        valid_in <= '0';
        key_in <= (others => '0');
        activity_in <= (others => '0');
        
        report "Data injection complete. Waiting for pipeline to flush...";
        
        -- Wait for the last packet to clear the 35-cycle latency
        wait for CLK_PERIOD * 50;

        -- 3. Read the Logger Memory and write to output file
        report "Dumping Hardware Logger to file...";
        
        for i in 0 to 15 loop
            read_addr <= std_logic_vector(to_unsigned(i, 4));
            wait for CLK_PERIOD; -- Give BRAM 1 cycle to output data
            
            -- If the slot isn't empty, write it to our text file
            if unsigned(read_key_out) /= 0 then
                hwrite(v_oline, read_key_out);
                write(v_oline, string'(" "));
                hwrite(v_oline, read_count_out);
                writeline(output_file, v_oline);
            end if;
        end loop;

        report "Simulation Complete. Check hardware_heavy_hitters.txt";
        
        -- End simulation (forces Vivado to stop)
        std.env.stop;
        wait;
    end process;

end sim;