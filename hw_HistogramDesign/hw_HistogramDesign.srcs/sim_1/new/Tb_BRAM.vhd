library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Tb_BRAM is
end Tb_BRAM;

architecture Tb of Tb_BRAM is

constant T : time := 20 ns;
signal clk, wea, ena : std_logic := '0';
signal din, dout : std_logic_vector(31 downto 0) := (others => '0'); 
signal addr : std_logic_vector(9 downto 0) := (others => '0'); 

component xilinx_single_port_ram_read_first is
generic (
    RAM_WIDTH : integer := 32;                      -- Specify RAM data width
    RAM_DEPTH : integer := 1024                     -- Specify RAM depth (number of entries)
    );

port (
        addra : in std_logic_vector(9 downto 0);     -- Address bus, width determined from RAM_DEPTH
        clka  : in std_logic;                       			  -- Clock
        wea   : in std_logic;                       			  -- Write enable
        ena   : in std_logic;                       			  -- RAM Enable, for additional power savings, disable port when not in use
        douta : out std_logic_vector(RAM_WIDTH-1 downto 0)   			  -- RAM output data
    );

end component;

begin
    
    clk <= not clk after T / 2;
    process(clk)
    begin
        if rising_edge(clk) then
            if wea = '1' then
                addr <= addr + 1;
            end if;
        end if;
    end process;
   
    wea <= '1' after 2 * T;
    ena <= '1' after 2 * T;
    
    RAM : xilinx_single_port_ram_read_first port map (
        addra => addr,
        clka => clk,
        wea => wea,
        ena => ena,
        douta => dout
    );
    

end Tb;
