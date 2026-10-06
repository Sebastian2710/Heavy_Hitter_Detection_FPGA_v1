library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_controller is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        
        -- Trigger from Epoch Controller
        flush_done     : in  std_logic;
        
        -- Interface to Heavy Hitter Logger
        read_addr      : out std_logic_vector(3 downto 0);
        read_key_in    : in  std_logic_vector(31 downto 0);
        read_count_in  : in  std_logic_vector(31 downto 0);
        clear_log      : out std_logic;
        
        -- Interface to Nandland UART TX
        tx_byte        : out std_logic_vector(7 downto 0);
        tx_dv          : out std_logic;
        tx_active      : in  std_logic;
        tx_done        : in  std_logic
    );
end uart_tx_controller;

architecture rtl of uart_tx_controller is

    type state_type is (IDLE, FETCH, SEND_BYTE, WAIT_UART);
    signal current_state : state_type;
    
    signal slot_counter : integer range 0 to 15 := 0;
    signal byte_counter : integer range 0 to 7 := 0;

begin

    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= IDLE;
            slot_counter  <= 0;
            byte_counter  <= 0;
            read_addr     <= (others => '0');
            clear_log     <= '0';
            tx_byte       <= (others => '0');
            tx_dv         <= '0';
            
        elsif rising_edge(clk) then
            
            -- Default single-cycle pulses
            clear_log <= '0';
            tx_dv     <= '0';
            
            case current_state is
            
                when IDLE =>
                    slot_counter <= 0;
                    byte_counter <= 0;
                    
                    -- Wait for the epoch sweep to finish
                    if flush_done = '1' then
                        current_state <= FETCH;
                    end if;
                    
                when FETCH =>
                    -- Output the current slot address to the logger
                    read_addr <= std_logic_vector(to_unsigned(slot_counter, 4));
                    
                    -- Wait exactly one clock cycle for the logger registers to output data
                    current_state <= SEND_BYTE;
                    
                when SEND_BYTE =>
                    -- Multiplex the 64-bit record into 8-bit chunks (Big-Endian sequence)
                    case byte_counter is
                        when 0 => tx_byte <= read_key_in(31 downto 24);
                        when 1 => tx_byte <= read_key_in(23 downto 16);
                        when 2 => tx_byte <= read_key_in(15 downto 8);
                        when 3 => tx_byte <= read_key_in(7 downto 0);
                        when 4 => tx_byte <= read_count_in(31 downto 24);
                        when 5 => tx_byte <= read_count_in(23 downto 16);
                        when 6 => tx_byte <= read_count_in(15 downto 8);
                        when 7 => tx_byte <= read_count_in(7 downto 0);
                        when others => null;
                    end case;
                    
                    tx_dv <= '1'; -- Signal Nandland core to begin transmitting
                    current_state <= WAIT_UART;
                    
                when WAIT_UART =>
                    -- Hold steady until the UART core finishes sending the byte
                    if tx_done = '1' then
                        if byte_counter = 7 then
                            byte_counter <= 0;
                            
                            if slot_counter = 15 then
                                -- All 16 slots sent. Wipe the logger and go back to sleep.
                                clear_log <= '1';
                                current_state <= IDLE;
                            else
                                -- Move to the next logger slot
                                slot_counter <= slot_counter + 1;
                                current_state <= FETCH;
                            end if;
                        else
                            -- Move to the next byte in the current slot
                            byte_counter <= byte_counter + 1;
                            current_state <= SEND_BYTE;
                        end if;
                    end if;
                    
            end case;
        end if;
    end process;

end rtl;