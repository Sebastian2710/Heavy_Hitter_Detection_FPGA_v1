library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity epoch_controller is
    generic (
        -- At 100 MHz, 10,000,000 cycles = 100 milliseconds
        EPOCH_CYCLES : integer := 200 
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Outputs taking control of the Memory Pipelines
        flush_enable : out std_logic;
        flush_addr   : out std_logic_vector(10 downto 0)
    );
end epoch_controller;

architecture rtl of epoch_controller is

    type state_type is (NORMAL_OP, FLUSHING);
    signal current_state : state_type;
    
    -- Timers and counters
    signal epoch_timer : integer range 0 to EPOCH_CYCLES := 0;
    signal addr_counter : unsigned(10 downto 0) := (others => '0');

begin

    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= NORMAL_OP;
            epoch_timer   <= 0;
            addr_counter  <= (others => '0');
            flush_enable  <= '0';
            flush_addr    <= (others => '0');
            
        elsif rising_edge(clk) then
            
            case current_state is
            
                when NORMAL_OP =>
                    flush_enable <= '0';
                    addr_counter <= (others => '0');
                    
                    -- Count up until the epoch window is reached
                    if epoch_timer >= EPOCH_CYCLES - 1 then
                        epoch_timer   <= 0;
                        current_state <= FLUSHING;
                    else
                        epoch_timer   <= epoch_timer + 1;
                    end if;
                    
                when FLUSHING =>
                    -- Assert the override flags
                    flush_enable <= '1';
                    flush_addr   <= std_logic_vector(addr_counter);
                    
                    -- Sweep through all 2048 addresses
                    if addr_counter = 2047 then
                        current_state <= NORMAL_OP;
                    else
                        addr_counter  <= addr_counter + 1;
                    end if;
                    
            end case;
            
        end if;
    end process;

end rtl;