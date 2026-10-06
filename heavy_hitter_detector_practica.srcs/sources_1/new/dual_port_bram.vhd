library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dual_port_bram is
    port (
        clk   : in  std_logic;
        wea   : in  std_logic;                       -- Write Enable port A
        addra : in  std_logic_vector(10 downto 0);   -- Write Address port A
        dia   : in  std_logic_vector(31 downto 0);   -- Data In port A
        addrb : in  std_logic_vector(10 downto 0);   -- Read Address port B
        dob   : out std_logic_vector(31 downto 0)    -- Data Out port B
    );
end dual_port_bram;

architecture rtl of dual_port_bram is
    -- Define RAM: 2048 rows (2^11) of 32-bit vectors
    type ram_type is array (0 to 2047) of std_logic_vector(31 downto 0);
    signal RAM : ram_type := (others => (others => '0'));
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Port A: Write Operation
            if wea = '1' then
                RAM(to_integer(unsigned(addra))) <= dia;
            end if;
            
            -- Port B: Read Operation (Continuous read)
            dob <= RAM(to_integer(unsigned(addrb)));
        end if;
    end process;
end rtl;