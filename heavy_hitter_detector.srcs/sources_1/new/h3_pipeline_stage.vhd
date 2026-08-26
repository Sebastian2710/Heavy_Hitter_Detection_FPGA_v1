library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity h3_pipeline_stage is
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        
        -- Inputs from the current bit and the matrix
        current_key_bit  : in  std_logic;
        matrix_vector    : in  std_logic_vector(10 downto 0);
        
        -- The cumulative hash value passed from the previous stage
        partial_hash_in  : in  std_logic_vector(10 downto 0);
        
        -- The newly computed hash value, registered for the next stage
        partial_hash_out : out std_logic_vector(10 downto 0)
    );
end h3_pipeline_stage;

architecture rtl of h3_pipeline_stage is
    
    -- Internal combinatorial signals
    signal masked_vector : std_logic_vector(10 downto 0);
    signal xor_result    : std_logic_vector(10 downto 0);

begin

    -- =========================================================================
    -- COMBINATORIAL LOGIC (Instantaneous Math)
    -- =========================================================================
    
    -- Step 1: The AND Operation (Bitwise Masking)
    -- If the key bit is 1, pass the matrix vector. If 0, pass all zeros.
    masked_vector <= matrix_vector when (current_key_bit = '1') else (others => '0');
    
    -- Step 2: The XOR Operation
    -- Combine the masked vector with the partial hash from the previous stage
    xor_result <= partial_hash_in xor masked_vector;


    -- =========================================================================
    -- SEQUENTIAL LOGIC (Pipeline Registers)
    -- =========================================================================
    
    process(clk, rst)
    begin
        if rst = '1' then
            -- Asynchronous reset instantly clears the partial hash
            partial_hash_out <= (others => '0');
            
        elsif rising_edge(clk) then
            -- Capture the completed XOR result and lock it in for the next clock cycle
            partial_hash_out <= xor_result;
        end if;
    end process;

end rtl;