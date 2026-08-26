library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hft_cms_top is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        
        -- Live ITCH Stream Inputs
        key_in         : in  std_logic_vector(31 downto 0);
        activity_in    : in  std_logic_vector(31 downto 0);
        valid_in       : in  std_logic;
        
        -- Dynamic Threshold Input
        threshold      : in  std_logic_vector(31 downto 0);
        
        -- Output Interface (PC Read Bridge)
        read_addr      : in  std_logic_vector(3 downto 0);
        read_key_out   : out std_logic_vector(31 downto 0);
        read_count_out : out std_logic_vector(31 downto 0)
    );
end hft_cms_top;

architecture structural of hft_cms_top is

    -- =========================================================================
    -- COMPONENT DECLARATIONS
    -- =========================================================================

    component epoch_controller
        port (
            clk          : in  std_logic;
            rst          : in  std_logic;
            flush_enable : out std_logic;
            flush_addr   : out std_logic_vector(10 downto 0)
        );
    end component;

    component cms_row
        generic ( ROW_ID : integer );
        port (
            clk               : in  std_logic;
            rst               : in  std_logic;
            key_in            : in  std_logic_vector(31 downto 0);
            activity_in       : in  std_logic_vector(31 downto 0);
            valid_in          : in  std_logic;
            flush_enable      : in  std_logic;
            flush_addr        : in  std_logic_vector(10 downto 0);
            updated_count_out : out std_logic_vector(31 downto 0);
            valid_out         : out std_logic
        );
    end component;

    component heavy_hitter_detector
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            key_in          : in  std_logic_vector(31 downto 0);
            count_row_1     : in  std_logic_vector(31 downto 0);
            count_row_2     : in  std_logic_vector(31 downto 0);
            count_row_3     : in  std_logic_vector(31 downto 0);
            count_row_4     : in  std_logic_vector(31 downto 0);
            count_row_5     : in  std_logic_vector(31 downto 0);
            count_row_6     : in  std_logic_vector(31 downto 0);
            count_row_7     : in  std_logic_vector(31 downto 0);
            valid_in        : in  std_logic;
            threshold       : in  std_logic_vector(31 downto 0);
            key_out         : out std_logic_vector(31 downto 0);
            is_heavy_hitter : out std_logic;
            valid_out       : out std_logic
        );
    end component;
    
    component heavy_hitter_logger
        port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            key_in          : in  std_logic_vector(31 downto 0);
            count_in        : in  std_logic_vector(31 downto 0);
            is_heavy_hitter : in  std_logic;
            valid_in        : in  std_logic;
            read_addr       : in  std_logic_vector(3 downto 0);
            read_key_out    : out std_logic_vector(31 downto 0);
            read_count_out  : out std_logic_vector(31 downto 0)
        );
    end component;

    -- =========================================================================
    -- INTERNAL WIRING SIGNALS
    -- =========================================================================

    -- Epoch signals
    signal int_flush_en   : std_logic;
    signal int_flush_addr : std_logic_vector(10 downto 0);

    -- Row output signals
    signal count_r1, count_r2, count_r3, count_r4 : std_logic_vector(31 downto 0);
    signal count_r5, count_r6, count_r7           : std_logic_vector(31 downto 0);
    signal row_valid                              : std_logic;
    
    -- Detector output signals
    signal det_key_out   : std_logic_vector(31 downto 0);
    signal det_is_hh     : std_logic;
    signal det_valid_out : std_logic;

begin

    -- =========================================================================
    -- 1. THE CONTROL PATH (Epoch Timer)
    -- =========================================================================
    epoch_ctrl_inst : epoch_controller
        port map (
            clk          => clk,
            rst          => rst,
            flush_enable => int_flush_en,
            flush_addr   => int_flush_addr
        );

    -- =========================================================================
    -- 2. THE DATA PATH (Parallel Count-min Sketch Rows)
    -- =========================================================================
    row_1 : cms_row generic map (ROW_ID => 1) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r1, valid_out => row_valid
    );
    row_2 : cms_row generic map (ROW_ID => 2) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r2, valid_out => open
    );
    row_3 : cms_row generic map (ROW_ID => 3) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r3, valid_out => open
    );
    row_4 : cms_row generic map (ROW_ID => 4) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r4, valid_out => open
    );
    row_5 : cms_row generic map (ROW_ID => 5) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r5, valid_out => open
    );
    row_6 : cms_row generic map (ROW_ID => 6) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r6, valid_out => open
    );
    row_7 : cms_row generic map (ROW_ID => 7) port map (
        clk => clk, rst => rst, key_in => key_in, activity_in => activity_in, valid_in => valid_in,
        flush_enable => int_flush_en, flush_addr => int_flush_addr, updated_count_out => count_r7, valid_out => open
    );

    -- =========================================================================
    -- 3. THE DECISION ENGINE (Heavy Hitter Detector)
    -- =========================================================================
    hh_detector_inst : heavy_hitter_detector
        port map (
            clk             => clk,
            rst             => rst,
            key_in          => key_in,  
            count_row_1     => count_r1,
            count_row_2     => count_r2,
            count_row_3     => count_r3,
            count_row_4     => count_r4,
            count_row_5     => count_r5,
            count_row_6     => count_r6,
            count_row_7     => count_r7,
            valid_in        => row_valid,
            threshold       => threshold,
            key_out         => det_key_out,
            is_heavy_hitter => det_is_hh,
            valid_out       => det_valid_out
        );

    -- =========================================================================
    -- 4. THE OUTPUT MODULE (Logger)
    -- =========================================================================
    hh_logger_inst : heavy_hitter_logger
        port map (
            clk             => clk,
            rst             => rst,
            key_in          => det_key_out,
            count_in        => count_r1,    -- Logging Row 1's count as the approximation
            is_heavy_hitter => det_is_hh,
            valid_in        => det_valid_out,
            read_addr       => read_addr,
            read_key_out    => read_key_out,
            read_count_out  => read_count_out
        );

end structural;