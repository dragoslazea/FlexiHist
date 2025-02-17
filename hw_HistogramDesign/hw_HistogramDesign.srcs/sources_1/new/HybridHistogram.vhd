library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity HybridHistogram is
    Generic (
        NUM_COARSE_SIMPLE_BUCKETS : integer := 4;
        NUM_COARSE_DISTINCT_BUCKETS : integer := 4;
        NUM_COARSE_BLOOM_BUCKETS : integer := 4;
        NUM_COARSE_COUNTING_BLOOM_BUCKETS : integer := 4;
        NUM_FINE_BUCKETS : integer := 4;
        NUM_SUB_BUCKETS : integer := 10
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
end HybridHistogram;

architecture Structural of HybridHistogram is

component GenericBucket is
    Generic (
        BUCKET_ID : integer := 0;
        BUCKET_TYPE : integer := 0;
        MAX_BUCKET_SIZE : integer := 512;
        NUM_SUB_BUCKETS : integer := 1;
        NUM_HASHES : integer range 3 to 5 := 4;
        FILTER_SIZE_BITS : integer range 1 to 32 := 7
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

constant NUM_BUCKETS : integer := NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS + NUM_COARSE_BLOOM_BUCKETS + NUM_COARSE_COUNTING_BLOOM_BUCKETS + NUM_FINE_BUCKETS + 2;

type bucket_data_type is array (0 to NUM_BUCKETS - 1) of std_logic_vector(67 downto 0);
type dest_data_type is array (0 to NUM_BUCKETS - 1) of std_logic_vector(31 downto 0);

signal data : bucket_data_type := (others => (others => '0'));
signal dests : dest_data_type := (others => (others => '0'));
signal valid_array, ready_array : std_logic_vector(0 to NUM_BUCKETS - 1) := (others => '0');

begin

    buckets_gen : for i in 0 to NUM_BUCKETS - 1 generate
        first_bucket : if i = 0 generate
            b : GenericBucket generic map (BUCKET_TYPE => 2, BUCKET_ID => i) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => s_axis_in_tvalid,
                s_axis_in_tready => s_axis_in_tready,
                s_axis_in_tdata => s_axis_in_tdata,
                s_axis_in_tdest => s_axis_in_tdest,
                m_axis_out_tvalid => valid_array(i),
                m_axis_out_tready => ready_array(i),
                m_axis_out_tdata => data(i),
                m_axis_out_tdest => dests(i)
            );
        end generate first_bucket;
    
        coarse_simple_bucket : if (i > 0 and i <= NUM_COARSE_SIMPLE_BUCKETS)  generate
            b : GenericBucket generic map (BUCKET_TYPE => 1, BUCKET_ID => i) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => valid_array(i - 1),
                s_axis_in_tready => ready_array(i - 1),
                s_axis_in_tdata => data(i - 1),
                s_axis_in_tdest => dests(i - 1),
                m_axis_out_tvalid => valid_array(i),
                m_axis_out_tready => ready_array(i),
                m_axis_out_tdata => data(i),
                m_axis_out_tdest => dests(i)
            );
        end generate coarse_simple_bucket;
        
        coarse_distinct_bucket : if (i > NUM_COARSE_SIMPLE_BUCKETS and i <= NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS)  generate
            b : GenericBucket generic map (BUCKET_TYPE => 4, BUCKET_ID => i) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => valid_array(i - 1),
                s_axis_in_tready => ready_array(i - 1),
                s_axis_in_tdata => data(i - 1),
                s_axis_in_tdest => dests(i - 1),
                m_axis_out_tvalid => valid_array(i),
                m_axis_out_tready => ready_array(i),
                m_axis_out_tdata => data(i),
                m_axis_out_tdest => dests(i)
            );
        end generate coarse_distinct_bucket;
        
        fine_bucket : if (i > NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS and i <= NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS + NUM_FINE_BUCKETS)  generate
            b : GenericBucket generic map (BUCKET_TYPE => 0, BUCKET_ID => i, NUM_SUB_BUCKETS => NUM_SUB_BUCKETS) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => valid_array(i - 1),
                s_axis_in_tready => ready_array(i - 1),
                s_axis_in_tdata => data(i - 1),
                s_axis_in_tdest => dests(i - 1),
                m_axis_out_tvalid => valid_array(i),
                m_axis_out_tready => ready_array(i),
                m_axis_out_tdata => data(i),
                m_axis_out_tdest => dests(i)
            );
        end generate fine_bucket;
        
        coarse_counting_bloom_bucket : if (i > NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS + NUM_FINE_BUCKETS and i <= NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS + NUM_FINE_BUCKETS + NUM_COARSE_COUNTING_BLOOM_BUCKETS)  generate
            b : GenericBucket generic map (BUCKET_TYPE => 6, BUCKET_ID => i, NUM_SUB_BUCKETS => NUM_SUB_BUCKETS) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => valid_array(i - 1),
                s_axis_in_tready => ready_array(i - 1),
                s_axis_in_tdata => data(i - 1),
                s_axis_in_tdest => dests(i - 1),
                m_axis_out_tvalid => valid_array(i),
                m_axis_out_tready => ready_array(i),
                m_axis_out_tdata => data(i),
                m_axis_out_tdest => dests(i)
            );
        end generate coarse_counting_bloom_bucket;
        
        coarse_bloom_bucket : if (i > NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS + NUM_FINE_BUCKETS + NUM_COARSE_COUNTING_BLOOM_BUCKETS and i <= NUM_COARSE_SIMPLE_BUCKETS + NUM_COARSE_DISTINCT_BUCKETS + NUM_FINE_BUCKETS + NUM_COARSE_COUNTING_BLOOM_BUCKETS + NUM_COARSE_BLOOM_BUCKETS)  generate
            b : GenericBucket generic map (BUCKET_TYPE => 5, BUCKET_ID => i, NUM_SUB_BUCKETS => NUM_SUB_BUCKETS) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => valid_array(i - 1),
                s_axis_in_tready => ready_array(i - 1),
                s_axis_in_tdata => data(i - 1),
                s_axis_in_tdest => dests(i - 1),
                m_axis_out_tvalid => valid_array(i),
                m_axis_out_tready => ready_array(i),
                m_axis_out_tdata => data(i),
                m_axis_out_tdest => dests(i)
            );
        end generate coarse_bloom_bucket;        
        
        last_bucket : if i = NUM_BUCKETS - 1 generate
            b : GenericBucket generic map (BUCKET_TYPE => 3, BUCKET_ID => i) port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => valid_array(i - 1),
                s_axis_in_tready => ready_array(i - 1),
                s_axis_in_tdata => data(i - 1),
                s_axis_in_tdest => dests(i - 1),
                m_axis_out_tvalid => m_axis_out_tvalid,
                m_axis_out_tready => m_axis_out_tready,
                m_axis_out_tdata => m_axis_out_tdata,
                m_axis_out_tdest => m_axis_out_tdest
            );
        end generate last_bucket;
    
    end generate buckets_gen;


end Structural;
