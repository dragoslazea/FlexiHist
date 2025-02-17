library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use IEEE.STD_lOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Tb_FineGrainedBRAMBucket_simple is
end Tb_FineGrainedBRAMBucket_simple;

architecture Tb of Tb_FineGrainedBRAMBucket_simple is

component FineGrainedBRAMBucket is
    Generic (
        BUCKET_ID : integer := 0;
        NUM_SUB_BUCKETS_BITS : integer := 3
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

component ForwardingBRAMBasedBucket is
   Generic (
        BUCKET_ID : integer := 0;
        NUM_SUB_BUCKETS_BITS : integer := 10
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
signal low, high, test_conv : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
--signal val : STD_LOGIC_VECTOR (31 downto 0) := x"00000020";
signal in_val, val, dest_in, dest_out : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
signal i : integer := 2;
signal test_val, max : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');

type data_type is array (0 to 2000) of std_logic_vector (31 downto 0);
signal data : data_type := (others => (others => '0'));

signal rd_count, wr_count, configured_buckets : integer := 0;
signal total_buckets : integer := 1;
signal end_of_reading : std_logic := '0';
signal first : std_logic := '1';

begin
nrst <= '0', '1' after 4 * T;
    clk <= not clk after T / 2;
    
    low <= x"00000000";
    --high <= x"00002800";
    high <= x"00000020"; -- 32
    max <= x"00000020"; -- 32
    
    
    in_data <=  opcode & x"0000000000000000" when opcode = "0000" else
                opcode & high & low when opcode = "0001" else     
                opcode & x"00000000" & "0" & val(30 downto 0) when opcode = "0010" else     
                opcode & x"00000000" & "0" & val(30 downto 0) when opcode = "0011" else
                opcode & x"00000000" & "0" & val(30 downto 0) when opcode = "0100" else
                (others => '0');     
    
    in_valid <= '1' when end_of_reading = '0' else '0';
    out_ready <= '1';
    
    val <= in_val when end_of_reading = '0' else test_val;

    process(clk)
    begin
        if rising_edge(clk) and nrst = '1' then
            if opcode = "0001" and configured_buckets < total_buckets then
                configured_buckets <= configured_buckets + 1;
--                low <= low + size;
            end if;
        end if;
    end process;
    
--    histo : FineGrainedBRAMBucket
--        generic map (NUM_SUB_BUCKETS_BITS => 3)
--        port map (
--            aclk => clk,
--            nrst => nrst,
--            s_axis_in_tvalid => in_valid,
--            s_axis_in_tready => in_ready,
--            s_axis_in_tdata => in_data,
--            s_axis_in_tdest => dest_in,
--            m_axis_out_tvalid => out_valid,
--            m_axis_out_tready => out_ready,
--            m_axis_out_tdata => out_data,
--            m_axis_out_tdest => dest_out
--        );

    histo : ForwardingBRAMBasedBucket
        generic map (NUM_SUB_BUCKETS_BITS => 3)
        port map (
            aclk => clk,
            nrst => nrst,
            s_axis_in_tvalid => in_valid,
            s_axis_in_tready => in_ready,
            s_axis_in_tdata => in_data,
            s_axis_in_tdest => dest_in,
            m_axis_out_tvalid => out_valid,
            m_axis_out_tready => out_ready,
            m_axis_out_tdata => out_data,
            m_axis_out_tdest => dest_out
        );
    
    process (clk)
        file input_file : text open read_mode is "simple_data.csv";
        variable in_line : line;
        variable rd_value : std_logic_vector(31 downto 0);
        
        function to_string(lvec: in std_logic_vector) return string is
            variable text: string(lvec'length-1 downto 0) := (others => '9');
        begin
            for k in lvec'range loop
                case lvec(k) is
                    when '0' => text(k) := '0';
                    when '1' => text(k) := '1';
                    when 'U' => text(k) := 'U';
                    when 'X' => text(k) := 'X';
                    when 'Z' => text(k) := 'Z';
                    when '-' => text(k) := '-';
                    when others => text(k) := '?';
                end case;
            end loop;
            
            return text;
        end function;
    
    begin
        if rising_edge(clk) then
            if nrst = '1' and end_of_reading = '0' then
                if not endfile(input_file) then     
                    if in_ready = '1' then
                        readline(input_file, in_line);
                        read(in_line, rd_value);
                        in_val <= rd_value;
                        rd_count <= rd_count + 1;
                        
                        if configured_buckets < total_buckets then
                            opcode <= "0001";
                        else
                            if rd_value(31) = '0' then
                                opcode <= "0010";
                            else
                                opcode <= "0011";
                            end if;
                        end if;
                    else

                    end if;
                else
                    file_close(input_file);
                    end_of_reading <= '1';
                end if;
            end if;
        end if;
    end process;
    
    process (clk)
        file results : text open write_mode is "C:\IVA\Research\histograms\HybridHistogramsOnStreamingData\results_in_memory_simple.csv";
        variable out_line : line;
        variable wr_value : std_logic_vector(31 downto 0);
        
        function to_string(lvec: in std_logic_vector) return string is
            variable text: string(lvec'length-1 downto 0) := (others => '9');
        begin
            for k in lvec'range loop
                case lvec(k) is
                    when '0' => text(k) := '0';
                    when '1' => text(k) := '1';
                    when 'U' => text(k) := 'U';
                    when 'X' => text(k) := 'X';
                    when 'Z' => text(k) := 'Z';
                    when '-' => text(k) := '-';
                    when others => text(k) := '?';
                end case;
            end loop;  
            
            return text;
        end function;
    
    begin
        if rising_edge(clk) then
            if nrst = '1' and out_valid = '1' and (out_data(67 downto 64) = "0011" or out_data(67 downto 64) = "0100") then
                if out_data(31 downto 0) < max then
                    write(out_line, to_integer(unsigned(out_data(31 downto 0))));
                    write(out_line, string'(", "));
                    write(out_line, to_integer(unsigned(out_data(63 downto 32))));
                    writeline(results, out_line);
                else
                    file_close(results);
                    report "execution finished";
                end if;
            end if;
        end if;
    end process;

end Tb;
