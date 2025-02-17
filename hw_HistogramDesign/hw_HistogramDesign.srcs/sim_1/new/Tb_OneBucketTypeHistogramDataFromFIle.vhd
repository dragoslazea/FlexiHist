library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use IEEE.STD_lOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Tb_OneBucketTypeHistogramDataFromFIle is
end Tb_OneBucketTypeHistogramDataFromFIle;

architecture Tb of Tb_OneBucketTypeHistogramDataFromFIle is

component OneBucketTypeHistogram is
    Generic (
        NUM_BUCKETS : integer := 4;
        BUCKET_TYPE : integer := 0;
        MAX_BUCKET_SIZE : integer := 512;
        NUM_SUB_BUCKETS : integer := 1;
        NUM_HASHES : integer range 3 to 5 := 4;
        FILTER_SIZE_BITS : integer := 7
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

component GenericBucket is
    Generic (
        BUCKET_ID : integer := 0;
        BUCKET_TYPE : integer := 6;
        MAX_BUCKET_SIZE : integer := 512;
        NUM_SUB_BUCKETS : integer := 128;
        NUM_HASHES : integer range 3 to 5 := 4;
        FILTER_SIZE_BITS : integer range 1 to 32 := 10
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
signal low, size, test_conv, size_or_high : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
signal in_val, val, dest_in, dest_out : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
signal i : integer := 2;
signal test_val, max : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
--signal high : STD_LOGIC_VECTOR (31 downto 0) := x"0000097E";
--signal high : STD_LOGIC_VECTOR (31 downto 0) := x"000004bf";
signal high : STD_LOGIC_VECTOR (31 downto 0) := x"000012fc";
type data_type is array (0 to 2000) of std_logic_vector (31 downto 0);
signal data : data_type := (others => (others => '0'));

signal rd_count, wr_count, configured_buckets : integer := 0;
signal total_buckets : integer := 1;
signal end_of_reading : std_logic := '0';
signal first : std_logic := '1';
--signal coarse_bucket_size : STD_LOGIC_VECTOR (31 downto 0) := x"000000DC";
--signal coarse_bucket_size : STD_LOGIC_VECTOR (31 downto 0) := x"0000097E"; -- for 2 buckets
--signal coarse_bucket_size : STD_LOGIC_VECTOR (31 downto 0) := x"000004bf"; -- for 4 buckets
signal coarse_bucket_size : STD_LOGIC_VECTOR (31 downto 0) := x"000012FC"; -- for 1 bucket

begin

    nrst <= '0', '1' after 2 * T;
    clk <= not clk after T / 2;
    
--    low <= x"00000000";
--    size <= x"000000DC";
    size <= x"00000016";
    
--    size_or_high <= high;
--    size_or_high <= size when configured_buckets >= 9 and configured_buckets < 12 else high;
       
    in_data <=  opcode & x"0000000000000000" when opcode = "0000" else
                opcode & high & low when opcode = "0001" else     
                opcode & x"00000000" & val when opcode = "0010" else     
                opcode & x"00000000" & val when opcode = "0011" else
                opcode & x"00000000" & val when opcode = "0100" else
                (others => '0');     
    
    in_valid <= '1';
    out_ready <= '1';
    
    val <= in_val when end_of_reading = '0' else test_val;
    
    process(clk)
    begin
        if rising_edge(clk) and nrst = '1' then 
            if configured_buckets = total_buckets then
--                if opcode < "0100" then
--                    opcode <= opcode + 1;
--                else
--                    opcode <= "0000";
--                end if;
                if end_of_reading = '1' then
                    opcode <= "0011";
--                    opcode <= "0100";
                    if test_val <= max and (opcode = "0011" or opcode = "0100") then
                        test_val <= test_val + 1;
                    end if;
                else 
                    opcode <= "0010";
                end if;
            else
                opcode <= "0001";
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) and nrst = '1' then
            if opcode = "0001" and configured_buckets < total_buckets then
--                if configured_buckets < total_buckets - 1 then
--                    low <= low + coarse_bucket_size;
--                    high <= high + coarse_bucket_size;
--                else
--                    low <= x"000012fe";
--                end if;
                low <= low + coarse_bucket_size;
                high <= high + coarse_bucket_size;
                configured_buckets <= configured_buckets + 1;
            end if;
        end if;
    end process;
    
--    histo : OneBucketTypeHistogram
--        generic map (
--            NUM_BUCKETS => 4,
--            NUM_SUB_BUCKETS => 10,
--            BUCKET_TYPE => 6, 
--            FILTER_SIZE_BITS => 7
--        )
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

    histo : GenericBucket
        generic map (
            NUM_SUB_BUCKETS => 10,
            BUCKET_TYPE => 6, 
            FILTER_SIZE_BITS => 10,
            NUM_HASHES => 3
        )
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
        file input_file : text open read_mode is "electrical_small.csv";
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
                    if in_ready = '1' and opcode = "0010" then
                        readline(input_file, in_line);
                        read(in_line, rd_value);
                        --in_valid <= '1';
                        in_val <= rd_value;
                        rd_count <= rd_count + 1;
                    else
                        --in_valid <= '0';
                    end if;
                else
                    file_close(input_file);
                    end_of_reading <= '1';
                end if;
            end if;
        end if;
    end process;
    
    max <= x"000012FC"; -- 4860
    
    process (clk)
        file results : text open write_mode is "C:\IVA\Research\histograms\HybridHistogramsOnStreamingData\results_counting_bloom_1_buck_1024_counters_good.csv";
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
            if nrst = '1' and out_valid = '1' and end_of_reading = '1' and (out_data(67 downto 64) = "0011" or out_data(67 downto 64) = "0100") then
                if out_data(31 downto 0) <= max then
                    write(out_line, to_integer(unsigned(out_data(31 downto 0))));
                    write(out_line, string'(", "));
                    write(out_line, to_integer(unsigned(out_data(63 downto 32))));
                    writeline(results, out_line);
                    wr_count <= wr_count + 1;
                else
                    file_close(results);
                    report "execution finished";
                end if;
            end if;
        end if;
    end process;


end Tb;
