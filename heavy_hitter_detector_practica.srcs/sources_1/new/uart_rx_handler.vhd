library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_handler is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        
        -- Inputs from Nandland uart_rx
        rx_dv         : in  std_logic;
        rx_byte       : in  std_logic_vector(7 downto 0);
        
        -- Outputs to Count-Min Sketch Array
        key_out       : out std_logic_vector(31 downto 0);
        activity_out  : out std_logic_vector(31 downto 0);
        valid_out     : out std_logic;
        
        -- Output to Epoch Controller
        flush_request : out std_logic
    );
end uart_rx_handler;

architecture rtl of uart_rx_handler is

    -- State tracking
    signal byte_counter : integer range 0 to 8 := 0;
    signal emit_flag    : std_logic := '0';
    
    -- Data holding registers
    signal opcode_reg   : std_logic_vector(7 downto 0) := (others => '0');
    signal key_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal act_reg      : std_logic_vector(31 downto 0) := (others => '0');

begin

    -- Wire the holding registers directly to the output ports
    key_out      <= key_reg;
    activity_out <= act_reg;

    process(clk, rst)
    begin
        if rst = '1' then
            byte_counter  <= 0;
            emit_flag     <= '0';
            opcode_reg    <= (others => '0');
            key_reg       <= (others => '0');
            act_reg       <= (others => '0');
            valid_out     <= '0';
            flush_request <= '0';
            
        elsif rising_edge(clk) then
            -- Default states for 1-cycle pulses
            valid_out     <= '0';
            flush_request <= '0';
            emit_flag     <= '0';
            
            -- If the emit flag was set on the previous cycle, fire the pulses now
            -- This ensures key_reg and act_reg are fully settled on the output pins
            if emit_flag = '1' then
                if opcode_reg = x"01" then
                    valid_out <= '1';
                elsif opcode_reg = x"02" then
                    flush_request <= '1';
                end if;
            end if;

            -- Handle incoming bytes from the UART core
            if rx_dv = '1' then
                case byte_counter is
                    when 0 => opcode_reg <= rx_byte;
                    
                    -- Big-Endian Key Assembly
                    when 1 => key_reg(31 downto 24) <= rx_byte;
                    when 2 => key_reg(23 downto 16) <= rx_byte;
                    when 3 => key_reg(15 downto 8)  <= rx_byte;
                    when 4 => key_reg(7 downto 0)   <= rx_byte;
                    
                    -- Big-Endian Activity Assembly
                    when 5 => act_reg(31 downto 24) <= rx_byte;
                    when 6 => act_reg(23 downto 16) <= rx_byte;
                    when 7 => act_reg(15 downto 8)  <= rx_byte;
                    
                    when 8 => 
                        act_reg(7 downto 0) <= rx_byte;
                        emit_flag <= '1'; -- Trigger output on the next clock edge
                        
                    when others =>
                        null;
                end case;
                
                -- Advance counter, wrapping back to 0 after byte 8
                if byte_counter = 8 then
                    byte_counter <= 0;
                else
                    byte_counter <= byte_counter + 1;
                end if;
            end if;
            
        end if;
    end process;

end rtl;