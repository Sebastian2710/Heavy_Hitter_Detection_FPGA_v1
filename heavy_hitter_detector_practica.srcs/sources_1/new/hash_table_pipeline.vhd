library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hash_table_pipeline is
    port (
        clk               : in  std_logic;
        rst               : in  std_logic; 
        
        -- Inputs from Hash Computation (Stage 1)
        hash_in           : in  std_logic_vector(10 downto 0);
        activity_in       : in  std_logic_vector(31 downto 0);
        valid_in          : in  std_logic;
        
        -- Flush Override Signals
        flush_enable      : in  std_logic;
        flush_addr        : in  std_logic_vector(10 downto 0);
        
        -- Output to Heavy Hitter Detector
        updated_count_out : out std_logic_vector(31 downto 0)
    );
end hash_table_pipeline;

architecture rtl of hash_table_pipeline is

    component dual_port_bram
        port (
            clk   : in  std_logic;
            wea   : in  std_logic;
            addra : in  std_logic_vector(10 downto 0);
            dia   : in  std_logic_vector(31 downto 0);
            addrb : in  std_logic_vector(10 downto 0);
            dob   : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Stage 1 to Stage 2 Registers
    signal hash_stg2     : std_logic_vector(10 downto 0);
    signal activity_stg2 : std_logic_vector(31 downto 0);
    signal valid_stg2    : std_logic;
    signal bram_dob      : std_logic_vector(31 downto 0);
    
    -- Forwarding Registers (To fix the 2-cycle hazard)
    signal use_forwarded_stg2   : std_logic;
    signal forwarded_count_stg2 : std_logic_vector(31 downto 0);
    
    -- Stage 2 to Stage 3 Registers
    signal hash_stg3     : std_logic_vector(10 downto 0);
    signal count_stg3    : std_logic_vector(31 downto 0);
    signal valid_stg3    : std_logic;

    -- Combinatorial signals
    signal match_at_stage1   : std_logic;
    signal safe_count_to_add : std_logic_vector(31 downto 0);
    signal new_computed_sum  : std_logic_vector(31 downto 0);
    
    -- Flush Multiplexer Signals
    signal bram_wea   : std_logic;
    signal bram_addra : std_logic_vector(10 downto 0);
    signal bram_dia   : std_logic_vector(31 downto 0);

begin

    -- =========================================================================
    -- BRAM WRITE PORT MULTIPLEXERS
    -- =========================================================================
    bram_wea   <= '1'               when (flush_enable = '1') else valid_stg3;
    bram_addra <= flush_addr        when (flush_enable = '1') else hash_stg3;
    bram_dia   <= (others => '0')   when (flush_enable = '1') else count_stg3;
    
    bram_inst : dual_port_bram
        port map (
            clk   => clk,
            wea   => bram_wea,    -- Updated to use the mux
            addra => bram_addra,  -- Updated to use the mux
            dia   => bram_dia,    -- Updated to use the mux
            addrb => hash_in,     -- Read port remains completely untouched
            dob   => bram_dob     
        );

    -- STAGE 1 COMBINATORIAL: Check for 2-cycle hazard
    -- Compare Memory Read stage (hash_in) with Memory Write stage (hash_stg3)
    match_at_stage1 <= '1' when (hash_in = hash_stg3) and (valid_stg3 = '1') else '0';

    -- STAGE 2 COMBINATORIAL: Resolve all hazards
    process(hash_stg2, hash_stg3, valid_stg3, bram_dob, count_stg3, use_forwarded_stg2, forwarded_count_stg2)
    begin
        if (hash_stg2 = hash_stg3) and (valid_stg3 = '1') then
            -- 1-Cycle Hazard: Match observed at computation stage
            safe_count_to_add <= count_stg3;
            
        elsif use_forwarded_stg2 = '1' then
            -- 2-Cycle Hazard: Match was observed at memory read stage in the previous cycle
            safe_count_to_add <= forwarded_count_stg2;
            
        else
            -- No hazard detected, BRAM data is safe
            safe_count_to_add <= bram_dob;
        end if;
    end process;

    -- The actual computation
    new_computed_sum <= std_logic_vector(unsigned(safe_count_to_add) + unsigned(activity_stg2));
    
    -- Only output the sum if this is a valid packet, otherwise output zeros
    updated_count_out <= new_computed_sum when valid_stg2 = '1' else (others => '0');

    -- Pipeline Registers
    process(clk, rst)
    begin
        if rst = '1' then
            hash_stg2            <= (others => '0');
            activity_stg2        <= (others => '0');
            valid_stg2           <= '0';
            use_forwarded_stg2   <= '0';
            forwarded_count_stg2 <= (others => '0');
            
            hash_stg3            <= (others => '0');
            count_stg3           <= (others => '0');
            valid_stg3           <= '0';
            
        elsif rising_edge(clk) then
            -- Stage 1 to Stage 2
            hash_stg2     <= hash_in;
            activity_stg2 <= activity_in;
            valid_stg2    <= valid_in;
            
            -- Carry the forwarded data if a 2-cycle hazard was detected
            use_forwarded_stg2   <= match_at_stage1;
            if match_at_stage1 = '1' then
                forwarded_count_stg2 <= count_stg3;
            end if;
            
            -- Stage 2 to Stage 3
            hash_stg3     <= hash_stg2;
            count_stg3    <= new_computed_sum;
            valid_stg3    <= valid_stg2;
        end if;
    end process;

end rtl;