library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Import the package containing all 7 random matrices
use work.h3_matrix_pkg.all;

entity h3_hash_computation is
    -- Add the generic here to receive the ID from the cms_row wrapper
    generic (
        ROW_ID : integer := 1
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
end h3_hash_computation;

architecture structural of h3_hash_computation is

    component h3_pipeline_stage
        port (
            clk              : in  std_logic;
            rst              : in  std_logic;
            current_key_bit  : in  std_logic;
            matrix_vector    : in  std_logic_vector(10 downto 0);
            partial_hash_in  : in  std_logic_vector(10 downto 0);
            partial_hash_out : out std_logic_vector(10 downto 0)
        );
    end component;

    -- Wiring arrays
    type hash_chain_array is array (0 to 32) of std_logic_vector(10 downto 0);
    signal hash_chain : hash_chain_array;

    type activity_delay_array is array (0 to 32) of std_logic_vector(31 downto 0);
    signal activity_chain : activity_delay_array;
    signal valid_chain    : std_logic_vector(32 downto 0);
    
    type key_delay_array is array (0 to 32) of std_logic_vector(31 downto 0);
    signal key_chain : key_delay_array;
    
begin

    hash_chain(0) <= (others => '0');
    activity_chain(0) <= activity_in;
    valid_chain(0)    <= valid_in;
    key_chain(0) <= key_in;
    gen_h3_pipeline: for i in 0 to 31 generate
        
        stage_inst : h3_pipeline_stage
            port map (
                clk              => clk,
                rst              => rst,
                -- THE FIX: Pull the bit from the traveling chain, not the raw input
                current_key_bit  => key_chain(i)(i), 
                matrix_vector    => ALL_MATRICES(ROW_ID)(i),
                partial_hash_in  => hash_chain(i),
                partial_hash_out => hash_chain(i + 1)
            );

        process(clk, rst)
        begin
            if rst = '1' then
                key_chain(i + 1)      <= (others => '0'); -- Added reset
                activity_chain(i + 1) <= (others => '0');
                valid_chain(i + 1)    <= '0';
            elsif rising_edge(clk) then
                key_chain(i + 1)      <= key_chain(i);    -- Added shift
                activity_chain(i + 1) <= activity_chain(i);
                valid_chain(i + 1)    <= valid_chain(i);
            end if;
        end process;
        
    end generate gen_h3_pipeline;

    hash_out     <= hash_chain(32);
    activity_out <= activity_chain(32);
    valid_out    <= valid_chain(32);

end structural;