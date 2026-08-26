library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_h3_hash_computation is
-- Testbenches do not have ports
end tb_h3_hash_computation;

architecture sim of tb_h3_hash_computation is

    component h3_hash_computation
        port (
            clk          : in  std_logic;
            rst          : in  std_logic;
            key_in       : in  std_logic_vector(31 downto 0);
            activity_in  : in  std_logic_vector(31 downto 0);
            valid_in     : in  std_logic;
            hash_out     : out std_logic_vector(10 downto 0);
            activity_out : out std_logic_vector(31 downto 0);
            valid_out    : out std_logic
        );
    end component;

    -- Signals
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '0';
    signal key_in       : std_logic_vector(31 downto 0) := (others => '0');
    signal activity_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_in     : std_logic := '0';
    
    signal hash_out     : std_logic_vector(10 downto 0);
    signal activity_out : std_logic_vector(31 downto 0);
    signal valid_out    : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    dut: h3_hash_computation
        port map (
            clk          => clk,
            rst          => rst,
            key_in       => key_in,
            activity_in  => activity_in,
            valid_in     => valid_in,
            hash_out     => hash_out,
            activity_out => activity_out,
            valid_out    => valid_out
        );

    -- Clock Generation
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus
    stim_proc: process
    begin
        -- 1. Initialize and Reset
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;

        -- 2. Test Case 1: Trigger only Bit 0
        -- We expect the output hash to perfectly match H3_MATRIX_1(0)
        key_in      <= x"00000001";
        activity_in <= x"0000000A"; -- Decimal 10
        valid_in    <= '1';
        wait for CLK_PERIOD;

        -- 3. Test Case 2: Trigger only Bit 1
        -- We expect the output hash to perfectly match H3_MATRIX_1(1)
        key_in      <= x"00000002";
        activity_in <= x"00000014"; -- Decimal 20
        valid_in    <= '1';
        wait for CLK_PERIOD;

        -- 4. Idle the pipeline and wait for the 32-cycle latency
        key_in      <= (others => '0');
        activity_in <= (others => '0');
        valid_in    <= '0';
        
        -- Wait enough time for both packets to clear the 32 stages (320ns + padding)
        wait for CLK_PERIOD * 35;
        
        wait;
    end process;

end sim;