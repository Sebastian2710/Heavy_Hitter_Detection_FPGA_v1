library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_hash_table_pipeline is
-- Testbenches do not have ports
end tb_hash_table_pipeline;

architecture sim of tb_hash_table_pipeline is

    -- Component Declaration
    component hash_table_pipeline
        port (
            clk               : in  std_logic;
            rst               : in  std_logic;
            hash_in           : in  std_logic_vector(10 downto 0);
            activity_in       : in  std_logic_vector(31 downto 0);
            valid_in          : in  std_logic;
            updated_count_out : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Signals to connect to the Device Under Test (DUT)
    signal clk               : std_logic := '0';
    signal rst               : std_logic := '0';
    signal hash_in           : std_logic_vector(10 downto 0) := (others => '0');
    signal activity_in       : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_in          : std_logic := '0';
    signal updated_count_out : std_logic_vector(31 downto 0);

    -- Clock period constant (100 MHz)
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the DUT
    dut: hash_table_pipeline
        port map (
            clk               => clk,
            rst               => rst,
            hash_in           => hash_in,
            activity_in       => activity_in,
            valid_in          => valid_in,
            updated_count_out => updated_count_out
        );

    -- Clock generation process
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- 1. Initialize and Reset
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;

        -- 2. NORMAL OPERATION (No hazards)
        -- Send Order A to address 10 with a volume of 5
        hash_in     <= std_logic_vector(to_unsigned(10, 11));
        activity_in <= std_logic_vector(to_unsigned(5, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        valid_in    <= '0'; -- Pause to let it flush through
        wait for CLK_PERIOD * 4;

        -- Send Order B to the SAME address (10) long after A finished. Volume = 15.
        -- Expected sum: 5 + 15 = 20
        hash_in     <= std_logic_vector(to_unsigned(10, 11));
        activity_in <= std_logic_vector(to_unsigned(15, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        valid_in    <= '0';
        wait for CLK_PERIOD * 4;

        -- 3. TEST 1-CYCLE HAZARD (Back-to-back same address)
        -- Cycle 1: Address 20, Volume 100
        hash_in     <= std_logic_vector(to_unsigned(20, 11));
        activity_in <= std_logic_vector(to_unsigned(100, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        -- Cycle 2: Address 20, Volume 50 (Arrives immediately after)
        -- Expected sum: 100 + 50 = 150
        hash_in     <= std_logic_vector(to_unsigned(20, 11));
        activity_in <= std_logic_vector(to_unsigned(50, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;

        valid_in    <= '0';
        wait for CLK_PERIOD * 4;

        -- 4. TEST 2-CYCLE HAZARD (Gap of 1 clock cycle)
        -- Cycle 1: Address 30, Volume 500
        hash_in     <= std_logic_vector(to_unsigned(30, 11));
        activity_in <= std_logic_vector(to_unsigned(500, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;

        -- Cycle 2: Address 99 (Unrelated order), Volume 10
        hash_in     <= std_logic_vector(to_unsigned(99, 11));
        activity_in <= std_logic_vector(to_unsigned(10, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;

        -- Cycle 3: Address 30, Volume 200 (Arrives while the 500 volume is in write stage)
        -- Expected sum for address 30: 500 + 200 = 700
        hash_in     <= std_logic_vector(to_unsigned(30, 11));
        activity_in <= std_logic_vector(to_unsigned(200, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;

        valid_in    <= '0';
        wait; -- End simulation
    end process;

end sim;