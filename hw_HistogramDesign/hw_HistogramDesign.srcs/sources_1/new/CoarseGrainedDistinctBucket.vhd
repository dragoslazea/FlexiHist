library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CoarseGrainedDistinctBucket is
    Generic (
        BUCKET_ID : integer := 0;
        MAX_BUCKET_SIZE : integer := 1024
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
end CoarseGrainedDistinctBucket;

architecture Arch of CoarseGrainedDistinctBucket is

component LatchedRelay is
  generic (
    WIDTH : integer := 16
  );
  port (
    clk      : in std_logic;
    rst      : in std_logic;
    
    in_valid : in std_logic;
    in_ready : out std_logic;
    in_data  : in std_logic_vector (WIDTH-1 downto 0);

    out_valid : out std_logic;
    out_ready : in std_logic;
    out_data  : out std_logic_vector (WIDTH-1 downto 0)
  );
end component;

signal low, high, count : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
signal data : STD_LOGIC_VECTOR(67 downto 0) := (others => '0');
signal is_configured, rst, data_valid, data_ready : STD_LOGIC := '0';
signal id, dest : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- id is currently unused
signal relay_in, relay_out : STD_LOGIC_VECTOR(99 downto 0) := (others => '0');

signal bit_array_distincts : STD_LOGIC_VECTOR(MAX_BUCKET_SIZE - 1 downto 0) := (others => '0');
signal max_distincts_pow2 : integer := MAX_BUCKET_SIZE;
signal distinct_count : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

begin
    
    rst <= not nrst;

    relay : LatchedRelay generic map (WIDTH => 100)
        port map (
                clk => aclk,
                rst => rst,
                in_valid => data_valid,
                in_ready => data_ready,
                in_data => relay_in,
                out_valid => m_axis_out_tvalid,
                out_ready => m_axis_out_tready,
                out_data => relay_out
        );
    
    relay_in <= dest & data;
    m_axis_out_tdata <= relay_out(67 downto 0);
    m_axis_out_tdest <= relay_out(99 downto 68);
    
    
    -- opcode = 0000 (NOOP)
    -- opcode = 0001 (CONFIG)
    -- opcode = 0010 (UPDATE)
    -- opcode = 0011 (READ)
    -- opcode = 0100 {SET ID)
    process(aclk)
        variable num_distincts_var : std_logic_vector(31 downto 0) := (others => '0');
        variable log2_num_distincts_var : integer := 0;
    begin
        if rising_edge(aclk) then
            if nrst = '1' then
                if s_axis_in_tvalid = '1' and data_ready = '1' then
                    case s_axis_in_tdata(67 downto 64) is
                        when "0000" => 
                            -- noop
                            data <= s_axis_in_tdata;
                        when "0001" =>
                            -- config
                            if is_configured = '0' then
                                low <= s_axis_in_tdata(31 downto 0);
                                high <= s_axis_in_tdata(63 downto 32);
                                data(67 downto 64) <= "0000";
                                data(63 downto 0) <= s_axis_in_tdata(63 downto 0);
                                is_configured <= '1';
                                
                                num_distincts_var := s_axis_in_tdata(63 downto 32) - s_axis_in_tdata(31 downto 0) + 1;
                                
                                -- compute the next power of 2
                                num_distincts_var := num_distincts_var - 1;
                                num_distincts_var := num_distincts_var or std_logic_vector(unsigned(num_distincts_var) srl 1);
                                num_distincts_var := num_distincts_var or std_logic_vector(unsigned(num_distincts_var) srl 2);
                                num_distincts_var := num_distincts_var or std_logic_vector(unsigned(num_distincts_var) srl 4);
                                num_distincts_var := num_distincts_var or std_logic_vector(unsigned(num_distincts_var) srl 8);
                                num_distincts_var := num_distincts_var or std_logic_vector(unsigned(num_distincts_var) srl 16);
                                num_distincts_var := num_distincts_var + 1;
                                
                                -- the position of the set bit is needed
                                for i in 0 to 31 loop
                                    if num_distincts_var(i) = '1' then
                                        log2_num_distincts_var := i;
                                        exit;
                                    end if;
                                end loop;
                                
--                                if num_distincts_var > 32 then
--                                    max_distincts_pow2 <= 32;
--                                else
--                                    max_distincts_pow2 <= to_integer(unsigned(num_distincts_var));
--                                end if;

                                max_distincts_pow2 <= log2_num_distincts_var;
                                
                            else
                                data <= s_axis_in_tdata;
                            end if;
                        when "0010" =>
                            -- update 
                            if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low and s_axis_in_tdata(31 downto 0) < high then
                                -- update bucket count
                                data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                data(63 downto 32) <= count + 1;
                                data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                count <= count + 1;
                                
                                if bit_array_distincts(to_integer(unsigned(s_axis_in_tdata(max_distincts_pow2 - 1 downto 0)))) = '0' then
                                    bit_array_distincts(to_integer(unsigned(s_axis_in_tdata(max_distincts_pow2 - 1 downto 0)))) <= '1';
                                    distinct_count <= distinct_count + 1;
                                end if;
                                
                            else 
                                data <= s_axis_in_tdata;
                            end if;
                        when "0011" =>
                            -- read
                            if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low and s_axis_in_tdata(31 downto 0) < high then
                                data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                if distinct_count /= 0 then
                                    data(63 downto 32) <= std_logic_vector(unsigned(count) / unsigned(distinct_count));
                                else
                                    data(63 downto 32) <= count;
                                end if;
                                data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                            else 
                                data <= s_axis_in_tdata;
                            end if;
                        when "0100" =>
                            -- read
                            if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low and s_axis_in_tdata(31 downto 0) < high then
                                data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                if distinct_count /= 0 then
                                    data(63 downto 32) <= std_logic_vector(unsigned(count) / unsigned(distinct_count));
                                else
                                    data(63 downto 32) <= count;
                                end if;
                                data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                            else 
                                data <= s_axis_in_tdata;
                            end if;
                        when others =>
                            data <= s_axis_in_tdata;
                    end case;
                end if;
                
                if is_configured = '1' or (is_configured = '0' and s_axis_in_tdata(67 downto 64) = "0001" and s_axis_in_tvalid = '1' and data_ready = '1') then
                    data_valid <= s_axis_in_tvalid;
                else
                    data_valid <= '0';
                end if;
                
                dest <= s_axis_in_tdest;
            else
                data <= (others => '0');
                low <= (others => '0');
                high <= (others => '0');
                count <= (others => '0');
                is_configured <= '0';
                bit_array_distincts <= (others => '0');
                distinct_count <= (others => '0');
            end if;
        end if;
    end process;

    s_axis_in_tready <= data_ready;

end Arch;
