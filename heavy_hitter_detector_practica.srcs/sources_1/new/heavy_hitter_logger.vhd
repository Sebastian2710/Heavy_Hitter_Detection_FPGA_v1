library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity heavy_hitter_logger is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Inputs from the Heavy Hitter Detector
        key_in          : in  std_logic_vector(31 downto 0);
        count_in        : in  std_logic_vector(31 downto 0); -- Route row_1 count here for logging
        is_heavy_hitter : in  std_logic;
        valid_in        : in  std_logic;
        
        -- Interface to read the logs (e.g., from a testbench or AXI bus)
        read_addr       : in  std_logic_vector(3 downto 0);
        read_key_out    : out std_logic_vector(31 downto 0);
        read_count_out  : out std_logic_vector(31 downto 0)
    );
end heavy_hitter_logger;

architecture rtl of heavy_hitter_logger is

    -- Define a custom record to hold both the price and its volume
    type hh_record is record
        key   : std_logic_vector(31 downto 0);
        count : std_logic_vector(31 downto 0);
    end record;

    -- Create an array of 16 records to act as our memory buffer
    type log_array is array (0 to 15) of hh_record;
    signal hh_memory : log_array;
    
    -- Pointer to track where the next heavy hitter should be saved
    signal write_ptr : unsigned(3 downto 0);

begin

    -- =========================================================================
    -- WRITE PROCESS: Save the heavy hitter when flagged
    -- =========================================================================
    process(clk, rst)
        -- Variables resolve instantly in VHDL processes
        variable found : boolean;
        variable f_idx : integer range 0 to 15;
    begin
        if rst = '1' then
            write_ptr <= (others => '0');
            -- Clear the memory
            for i in 0 to 15 loop
                hh_memory(i).key   <= (others => '0');
                hh_memory(i).count <= (others => '0');
            end loop;
            
        elsif rising_edge(clk) then
            -- Only save data if it is a valid packet AND flagged as a heavy hitter
            if valid_in = '1' and is_heavy_hitter = '1' then
                
                found := false;
                f_idx := 0;
                
                -- NEW: Check if the price is already in the logger
                -- This synthesizes into 16 parallel comparators
                for i in 0 to 15 loop
                    if hh_memory(i).key = key_in then
                        found := true;
                        f_idx := i;
                    end if;
                end loop;
                
                if found then
                    -- UPDATE existing slot (do not increment write_ptr)
                    hh_memory(f_idx).count <= count_in;
                else
                    -- SAVE NEW distinct heavy hitter
                    hh_memory(to_integer(write_ptr)).key   <= key_in;
                    hh_memory(to_integer(write_ptr)).count <= count_in;
                    
                    -- Move the pointer to the next slot (wraps around automatically)
                    write_ptr <= write_ptr + 1;
                end if;
                
            end if;
        end if;
    end process;

    -- =========================================================================
    -- READ PROCESS: Allow the outside world to inspect the memory continuously
    -- =========================================================================
    read_key_out   <= hh_memory(to_integer(unsigned(read_addr))).key;
    read_count_out <= hh_memory(to_integer(unsigned(read_addr))).count;

end rtl;