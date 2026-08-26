library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cms_row is
    generic (
        ROW_ID : integer := 1
    );
    port (
        clk               : in  std_logic;
        rst               : in  std_logic;
        
        -- Inputs directly from the ITCH data stream
        key_in            : in  std_logic_vector(31 downto 0);
        activity_in       : in  std_logic_vector(31 downto 0);
        valid_in          : in  std_logic;
        
        -- Flush Override Signals
        flush_enable      : in  std_logic;
        flush_addr        : in  std_logic_vector(10 downto 0);
        
        -- Outputs to the Heavy Hitter Detector
        updated_count_out : out std_logic_vector(31 downto 0);
        valid_out         : out std_logic
    );
end cms_row;

architecture structural of cms_row is

    -- 1. Declare the Hash Computation Pipeline
    component h3_hash_computation
        generic (
            ROW_ID : integer
        );
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

    -- 2. Declare the Memory Pipeline
    component hash_table_pipeline
        port (
            clk               : in  std_logic;
            rst               : in  std_logic;
            hash_in           : in  std_logic_vector(10 downto 0);
            activity_in       : in  std_logic_vector(31 downto 0);
            valid_in          : in  std_logic;
            -- Flush Override Signals
            flush_enable      : in  std_logic;
            flush_addr        : in  std_logic_vector(10 downto 0);
            
            updated_count_out : out std_logic_vector(31 downto 0)
        );
    end component;

    -- 3. Intermediate signals to wire the two blocks together
    signal intermediate_hash     : std_logic_vector(10 downto 0);
    signal intermediate_activity : std_logic_vector(31 downto 0);
    signal intermediate_valid    : std_logic;

begin

    -- Instantiate the 32-stage Hash Pipeline
    hash_block : h3_hash_computation
        generic map (
            ROW_ID => ROW_ID
        )
        port map (
            clk          => clk,
            rst          => rst,
            key_in       => key_in,
            activity_in  => activity_in,
            valid_in     => valid_in,
            
            -- Route outputs to the intermediate wires
            hash_out     => intermediate_hash,
            activity_out => intermediate_activity,
            valid_out    => intermediate_valid
        );

    -- Instantiate the 3-stage Memory Pipeline
    memory_block : hash_table_pipeline
        port map (
            clk               => clk,
            rst               => rst,
            
            -- Route inputs from the intermediate wires
            hash_in           => intermediate_hash,
            activity_in       => intermediate_activity,
            valid_in          => intermediate_valid,
            -- NEW: Wire the signals through
            flush_enable      => flush_enable,
            flush_addr        => flush_addr,
            -- Route the final sum to the outside world
            updated_count_out => updated_count_out
        );

    -- Align the final 'valid' signal for the Heavy Hitter Detector.
    -- The memory pipeline's combinatorial addition finishes exactly 1 clock cycle 
    -- after intermediate_valid goes high (Stage 2).
    process(clk, rst)
    begin
        if rst = '1' then
            valid_out <= '0';
        elsif rising_edge(clk) then
            valid_out <= intermediate_valid;
        end if;
    end process;

end structural;