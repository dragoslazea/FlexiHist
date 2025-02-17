library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Tb_CoarseBucket is
end Tb_CoarseBucket;

architecture Tb of Tb_CoarseBucket is

component GenericBucket is
    Generic (
        BUCKET_ID : integer := 0;
        BUCKET_TYPE : integer := 0;
        MAX_BUCKET_SIZE : integer := 512;
        NUM_SUB_BUCKETS : integer := 1;
        NUM_HASHES : integer range 3 to 5 := 4;
        FILTER_SIZE_BITS : integer := 128
    );
    Port ( 
        -- inputs
        aclk : in STD_LOGIC;
        nrst : in STD_LOGIC;
        
        s_axis_in_tvalid : in STD_LOGIC;
        s_axis_in_tready : out STD_LOGIC;
        s_axis_in_tdata : in STD_LOGIC_VECTOR(67 downto 0);
        s_axis_in_tdest : in STD_LOGIC_VECTOR(31 downto 0);
        
        -- outputs
        m_axis_out_tvalid : out STD_LOGIC;
        m_axis_out_tready : in STD_LOGIC;
        m_axis_out_tdata : out STD_LOGIC_VECTOR(67 downto 0);
        m_axis_out_tdest : out STD_LOGIC_VECTOR(31 downto 0)
    );
end component;

constant T : time := 20 ns;
signal nrst, clk, in_valid, in_ready, out_valid, out_ready : STD_LOGIC := '0';
signal in_data, out_data : STD_LOGIC_VECTOR (67 downto 0) := (others => '0'); 
signal opcode : STD_LOGIC_VECTOR (3 downto 0) := (others => '0'); 
signal low, high, val, in_dest, out_dest, id : STD_LOGIC_VECTOR (31 downto 0) := (others => '0'); 

begin

    b : GenericBucket generic map (BUCKET_TYPE => 5, BUCKET_ID => 0, NUM_HASHES => 3) port map (
            aclk => clk,
            nrst => nrst,
            s_axis_in_tvalid => in_valid,
            s_axis_in_tready => in_ready,
            s_axis_in_tdata => in_data,
            s_axis_in_tdest => in_dest,
            m_axis_out_tvalid => out_valid,
            m_axis_out_tready => out_ready,
            m_axis_out_tdata => out_data,
            m_axis_out_tdest => out_dest
    );
    
    nrst <= '0', '1' after 4 * T;
    clk <= not clk after T / 2;
    
    low <= x"00000004";
    high <= x"00000008";
    
    in_data <=  opcode & x"0000000000000000" when opcode = "0000" else
                opcode & high & low when opcode = "0001" else     
                opcode & x"00000000" & val when opcode = "0010" else     
                opcode & x"00000000" & val when opcode = "0011" else
                opcode & x"00000000" & id when opcode = "0100" else
                (others => '0');     
  
    in_valid <= '1';
    out_ready <= '1';
    
    opcode <= "0000", "0001" after 5 * T, "0010" after 6 * T, "0011" after 12 * T;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if in_valid = '1' and nrst = '1' then
                if opcode = "0010" and val < 7 then
                    val <= val + 1;
                end if;
            end if;
            
        end if;
    end process;

end Tb;
