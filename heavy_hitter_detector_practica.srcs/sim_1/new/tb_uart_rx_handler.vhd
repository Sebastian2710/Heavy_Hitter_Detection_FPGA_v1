library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_rx_handler is
end tb_uart_rx_handler;

architecture sim of tb_uart_rx_handler is

    component uart_rx_handler
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            rx_dv         : in  std_logic;
            rx_byte       : in  std_logic_vector(7 downto 0);
            key_out       : out std_logic_vector(31 downto 0);
            activity_out  : out std_logic_vector(31 downto 0);
            valid_out     : out std_logic;
            flush_request : out std_logic
        );
    end component;

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '0';
    signal rx_dv         : std_logic := '0';
    signal rx_byte       : std_logic_vector(7 downto 0) := (others => '0');
    signal key_out       : std_logic_vector(31 downto 0);
    signal activity_out  : std_logic_vector(31 downto 0);
    signal valid_out     : std_logic;
    signal flush_request : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    uut: uart_rx_handler port map (
        clk => clk, rst => rst,
        rx_dv => rx_dv, rx_byte => rx_byte,
        key_out => key_out, activity_out => activity_out,
        valid_out => valid_out, flush_request => flush_request
    );

    clk_process: process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
        -- By placing the procedure INSIDE the process, it manipulates 
        -- the exact signals directly without parameter-passing bugs.
        procedure send_byte(data : std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            rx_byte <= data;
            rx_dv <= '1';
            wait until rising_edge(clk);
            rx_dv <= '0';
            wait for CLK_PERIOD * 10;
        end procedure;
        
    begin
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 5;

        -- TEST 1: Send a DATA packet (Opcode 0x01, Price = x0000AAAA, Vol = x000003E8)
        send_byte(x"01");
        
        send_byte(x"00");
        send_byte(x"00");
        send_byte(x"AA");
        send_byte(x"AA");
        
        send_byte(x"00");
        send_byte(x"00");
        send_byte(x"03");
        send_byte(x"E8");

        wait for CLK_PERIOD * 20;

        -- TEST 2: Send an END_OF_WINDOW packet (Opcode 0x02, padding 0s)
        send_byte(x"02");
        for i in 1 to 8 loop
            send_byte(x"00");
        end loop;

        wait;
    end process;

end sim;