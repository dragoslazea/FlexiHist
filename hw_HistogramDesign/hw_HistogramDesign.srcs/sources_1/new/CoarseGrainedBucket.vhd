library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CoarseGrainedBucket is
    Generic (
        BUCKET_ID : integer := 0;
        BUCKET_TYPE : integer := 0
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
end CoarseGrainedBucket;

architecture Arch of CoarseGrainedBucket is

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
    intermediate_bucket : if BUCKET_TYPE = 1 generate
        process(aclk)
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
                                else
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0010" =>
                                -- update
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low and s_axis_in_tdata(31 downto 0) < high then
                                    -- update bucket count
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count +  1;
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                    count <= count + 1;
                                else 
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0011" =>
                                -- read
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low and s_axis_in_tdata(31 downto 0) < high then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count;
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                else 
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0100" =>
                                -- read
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low and s_axis_in_tdata(31 downto 0) < high then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count;
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
                end if;
            end if;
        end process;
    end generate intermediate_bucket; 
    
    leftmost_bucket : if BUCKET_TYPE = 2 generate
        process(aclk)
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
                                    low <= (others => '0');
                                    high <= s_axis_in_tdata(63 downto 32);
                                    data(67 downto 64) <= "0000";
                                    data(63 downto 0) <= s_axis_in_tdata(63 downto 0);
                                    is_configured <= '1';
                                else
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0010" =>
                                -- update
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) < high then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count +  1;
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                    count <= count + 1;
                                else 
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0011" =>
                                -- read
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) < high then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count;
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                else 
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0100" =>
                                -- read
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) < high then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count;
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
                end if;
            end if;
        end process;
    end generate leftmost_bucket;
    
    rightmost_bucket : if BUCKET_TYPE = 3 generate
        process(aclk)
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
                                    high <= (others => '1');
                                    data(67 downto 64) <= "0000";
                                    data(63 downto 0) <= s_axis_in_tdata(63 downto 0);
                                    is_configured <= '1';
                                else
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0010" =>
                                -- update
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count +  1;
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                    count <= count + 1;
                                else 
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0011" =>
                                -- read
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count;
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                else 
                                    data <= s_axis_in_tdata;
                                end if;
                            when "0100" =>
                                -- read
                                if is_configured = '1' and s_axis_in_tdata(31 downto 0) >= low then
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(63 downto 32) <= count;
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
                end if;
            end if;
        end process;
    end generate rightmost_bucket;
    

    s_axis_in_tready <= data_ready;

end Arch;