library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_hft_cms_top is
-- Testbenches have no ports
end tb_hft_cms_top;

architecture sim of tb_hft_cms_top is

    -- Component Declaration
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

    -- Signals to drive the inputs
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal key_in      : std_logic_vector(31 downto 0) := (others => '0');
    signal activity_in : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_in    : std_logic := '0';
    signal threshold   : std_logic_vector(31 downto 0) := (others => '0');
    signal read_addr   : std_logic_vector(3 downto 0) := (others => '0');

    -- Signals to monitor the outputs
    signal read_key_out   : std_logic_vector(31 downto 0);
    signal read_count_out : std_logic_vector(31 downto 0);

    -- Clock period definition (100 MHz)
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
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

    -- Clock process
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
        threshold <= std_logic_vector(to_unsigned(2500, 32)); -- Set Threshold to 2500
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 5;

        -- 2. Inject Packet 1: Price A, 1000 shares
        key_in      <= x"0000AAAA";
        activity_in <= std_logic_vector(to_unsigned(1000, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        -- Pull valid low to separate packets
        valid_in    <= '0';
        wait for CLK_PERIOD;

        -- 3. Inject Packet 2: Price B, 500 shares (Noise)
        key_in      <= x"0000BBBB";
        activity_in <= std_logic_vector(to_unsigned(500, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        valid_in    <= '0';
        wait for CLK_PERIOD;

        -- 4. Inject Packet 3: Price A, 2000 shares (Triggers Heavy Hitter)
        key_in      <= x"0000AAAA";
        activity_in <= std_logic_vector(to_unsigned(2000, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        -- Idle the bus and wait for the pipeline to finish processing
        key_in      <= (others => '0');
        activity_in <= (others => '0');
        valid_in    <= '0';
        
        -- Wait for the Epoch Timer to trigger (200 cycles) + 2048 cycles for the flush
        -- Total wait: ~2500 cycles (25 microseconds)
        wait for CLK_PERIOD * 2500;

        -- 5. Post-Flush Check: Inject Price A, 1000 shares
        -- If flush worked, this will NOT trigger a heavy hitter
        key_in      <= x"0000AAAA";
        activity_in <= std_logic_vector(to_unsigned(3000, 32));
        valid_in    <= '1';
        wait for CLK_PERIOD;
        
        key_in      <= (others => '0');
        activity_in <= (others => '0');
        valid_in    <= '0';

        -- Wait for the final packet to clear the pipeline
        wait for CLK_PERIOD * 50;

        -- 6. Read the Logger Memory (Address 0) to verify it caught Price A
        read_addr <= "0000";
        
        -- End of Simulation
        wait;
    end process;

end sim;