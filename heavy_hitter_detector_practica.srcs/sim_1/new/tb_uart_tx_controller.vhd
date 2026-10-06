library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_tx_controller is
end tb_uart_tx_controller;

architecture sim of tb_uart_tx_controller is

    component uart_tx_controller
        port (
            clk            : in  std_logic;
            rst            : in  std_logic;
            flush_done     : in  std_logic;
            read_addr      : out std_logic_vector(3 downto 0);
            read_key_in    : in  std_logic_vector(31 downto 0);
            read_count_in  : in  std_logic_vector(31 downto 0);
            clear_log      : out std_logic;
            tx_byte        : out std_logic_vector(7 downto 0);
            tx_dv          : out std_logic;
            tx_active      : in  std_logic;
            tx_done        : in  std_logic
        );
    end component;

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '0';
    signal flush_done    : std_logic := '0';
    signal read_addr     : std_logic_vector(3 downto 0);
    signal read_key_in   : std_logic_vector(31 downto 0) := (others => '0');
    signal read_count_in : std_logic_vector(31 downto 0) := (others => '0');
    signal clear_log     : std_logic;
    signal tx_byte       : std_logic_vector(7 downto 0);
    signal tx_dv         : std_logic;
    signal tx_active     : std_logic := '0';
    signal tx_done       : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;

begin

    uut: uart_tx_controller port map (
        clk => clk, rst => rst,
        flush_done => flush_done,
        read_addr => read_addr, read_key_in => read_key_in,
        read_count_in => read_count_in, clear_log => clear_log,
        tx_byte => tx_byte, tx_dv => tx_dv,
        tx_active => tx_active, tx_done => tx_done
    );

    -- Clock generation
    clk_process: process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Mock Logger: Dynamically generate dummy data based on the requested address
    mock_logger: process(read_addr)
    begin
        -- For slot 0: Key = AAAA0000, Count = BBBB0000
        -- For slot 1: Key = AAAA0001, Count = BBBB0001, etc.
        read_key_in   <= x"AAAA000" & read_addr;
        read_count_in <= x"BBBB000" & read_addr;
    end process;

    -- Mock Nandland UART TX: Synchronous state machine to simulate transmission
    mock_uart_tx: process(clk, rst)
        variable delay_count : integer := 0;
        variable is_transmitting : boolean := false;
    begin
        if rst = '1' then
            tx_active <= '0';
            tx_done   <= '0';
            delay_count := 0;
            is_transmitting := false;
            
        elsif rising_edge(clk) then
            -- Default pulse state
            tx_done <= '0';
            
            if is_transmitting then
                -- Simulate the baud rate delay (e.g., 10 clock cycles)
                if delay_count = 10 then
                    is_transmitting := false;
                    tx_active <= '0';
                    tx_done   <= '1'; -- Fire the completion pulse
                else
                    delay_count := delay_count + 1;
                end if;
            else
                -- Wait for the TX Readout Controller to push a byte
                if tx_dv = '1' then
                    is_transmitting := true;
                    tx_active <= '1';
                    delay_count := 0;
                end if;
            end if;
            
        end if;
    end process;

    -- Main stimulus
    stim_proc: process
    begin
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 5;

        -- Fire the trigger from the epoch controller
        flush_done <= '1';
        wait until rising_edge(clk);
        flush_done <= '0';

        -- Wait until the controller finishes the 128th byte and pulses clear_log
        wait until rising_edge(clk) and clear_log = '1';
        
        -- Observe the reset pulse before ending simulation
        wait for CLK_PERIOD * 20;
        wait;
    end process;

end sim;