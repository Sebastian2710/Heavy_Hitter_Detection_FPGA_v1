library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity heavy_hitter_detector is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- The price that triggered this update
        key_in          : in  std_logic_vector(31 downto 0);
        
        -- The 7 parallel counts from the Count-min Sketch rows
        count_row_1     : in  std_logic_vector(31 downto 0);
        count_row_2     : in  std_logic_vector(31 downto 0);
        count_row_3     : in  std_logic_vector(31 downto 0);
        count_row_4     : in  std_logic_vector(31 downto 0);
        count_row_5     : in  std_logic_vector(31 downto 0);
        count_row_6     : in  std_logic_vector(31 downto 0);
        count_row_7     : in  std_logic_vector(31 downto 0);
        
        -- Synchronized valid signal from the Top Array
        valid_in        : in  std_logic;
        
        -- The target threshold (can be dynamically updated from a CPU)
        threshold       : in  std_logic_vector(31 downto 0);
        
        -- Outputs
        key_out         : out std_logic_vector(31 downto 0);
        is_heavy_hitter : out std_logic;
        valid_out       : out std_logic
    );
end heavy_hitter_detector;

architecture rtl of heavy_hitter_detector is

    -- Stage 1 Pipeline Registers (Comparators)
    signal comp_1, comp_2, comp_3, comp_4 : std_logic;
    signal comp_5, comp_6, comp_7         : std_logic;
    
    signal key_stg1   : std_logic_vector(31 downto 0);
    signal valid_stg1 : std_logic;

    -- Stage 2 Pipeline Registers (AND Tree)
    signal heavy_hitter_flag : std_logic;
    
    signal key_stg2   : std_logic_vector(31 downto 0);
    signal valid_stg2 : std_logic;

begin

    process(clk, rst)
    begin
        if rst = '1' then
            -- Reset Stage 1
            comp_1 <= '0'; comp_2 <= '0'; comp_3 <= '0'; comp_4 <= '0';
            comp_5 <= '0'; comp_6 <= '0'; comp_7 <= '0';
            key_stg1   <= (others => '0');
            valid_stg1 <= '0';
            
            -- Reset Stage 2
            heavy_hitter_flag <= '0';
            key_stg2          <= (others => '0');
            valid_stg2        <= '0';
            
        elsif rising_edge(clk) then
            
            -- =================================================================
            -- STAGE 1: Parallel Comparisons
            -- =================================================================
            -- Check if each individual row's count meets or exceeds the threshold
            if unsigned(count_row_1) >= unsigned(threshold) then comp_1 <= '1'; else comp_1 <= '0'; end if;
            if unsigned(count_row_2) >= unsigned(threshold) then comp_2 <= '1'; else comp_2 <= '0'; end if;
            if unsigned(count_row_3) >= unsigned(threshold) then comp_3 <= '1'; else comp_3 <= '0'; end if;
            if unsigned(count_row_4) >= unsigned(threshold) then comp_4 <= '1'; else comp_4 <= '0'; end if;
            if unsigned(count_row_5) >= unsigned(threshold) then comp_5 <= '1'; else comp_5 <= '0'; end if;
            if unsigned(count_row_6) >= unsigned(threshold) then comp_6 <= '1'; else comp_6 <= '0'; end if;
            if unsigned(count_row_7) >= unsigned(threshold) then comp_7 <= '1'; else comp_7 <= '0'; end if;
            
            -- Pass the key and valid signals forward
            key_stg1   <= key_in;
            valid_stg1 <= valid_in;
            
            -- =================================================================
            -- STAGE 2: The Multi-Input AND Gate
            -- =================================================================
            -- If all 7 comparators output a '1', the AND chain evaluates to '1'
            heavy_hitter_flag <= comp_1 and comp_2 and comp_3 and comp_4 and 
                                 comp_5 and comp_6 and comp_7;
            
            -- Pass the key and valid signals forward again
            key_stg2   <= key_stg1;
            valid_stg2 <= valid_stg1;
            
        end if;
    end process;

    -- Map internal pipeline signals to physical output ports
    is_heavy_hitter <= heavy_hitter_flag;
    key_out         <= key_stg2;
    valid_out       <= valid_stg2;

end rtl;