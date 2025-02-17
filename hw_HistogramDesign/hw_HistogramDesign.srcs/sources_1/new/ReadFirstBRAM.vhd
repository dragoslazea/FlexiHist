
  --  Xilinx Single Port Read First RAM
  --  This code implements a parameterizable single-port read-first memory where when data
  --  is written to the memory, the output reflects the prior contents of the memory location.
  --  If the output data is not needed during writes or the last read value is desired to be
  --  retained, it is suggested to use No Change Mode example as it is more power efficient.
  --  If a reset or enable is not necessary, it may be tied off or removed from the code.
  --  Modify the parameters for the desired RAM characteristics.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity xilinx_single_port_ram_read_first is
generic (
    RAM_WIDTH : integer := 32;                      -- Specify RAM data width
    RAM_DEPTH_BITS : integer := 10                  -- Specify RAM depth (number of bits in address)
    );

port (
        addra : in std_logic_vector(RAM_DEPTH_BITS - 1 downto 0);     -- Address bus, width determined from RAM_DEPTH
--        dina : in std_logic_vector(RAM_WIDTH-1 downto 0);
        clka  : in std_logic;                       			  -- Clock
        wea   : in std_logic;                       			  -- Write enable
        ena   : in std_logic;                       			  -- RAM Enable, for additional power savings, disable port when not in use

        douta : out std_logic_vector(RAM_WIDTH - 1 downto 0)   			  -- RAM output data
    );

end xilinx_single_port_ram_read_first;

architecture rtl of xilinx_single_port_ram_read_first is

constant C_RAM_WIDTH : integer := RAM_WIDTH;
constant C_RAM_DEPTH : integer := 2 ** RAM_DEPTH_BITS;

signal douta_reg : std_logic_vector(C_RAM_WIDTH-1 downto 0) := (others => '0');
type ram_type is array (C_RAM_DEPTH-1 downto 0) of std_logic_vector (C_RAM_WIDTH-1 downto 0);          -- 2D Array Declaration for RAM signal
signal ram_data : std_logic_vector(C_RAM_WIDTH-1 downto 0) := (others => '0');

-- Following code defines RAM

signal ram_memory : ram_type := (others => (others => '0'));

begin

process(clka)
begin
    if rising_edge(clka) then
        if(ena = '1') then
            ram_data <= ram_memory(to_integer(unsigned(addra)));
        end if;
    end if;
end process;

process(clka)
begin
    if rising_edge(clka) then
        if(ena = '1') then
            if(wea = '1') then
                ram_memory(to_integer(unsigned(addra))) <= ram_data+1;
            end if;
        end if;
    end if;
end process;

douta <= ram_data;


end rtl;

						
						