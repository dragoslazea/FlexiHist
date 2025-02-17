library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity GenericBucket is
    Generic (
        BUCKET_ID : integer := 0;
        BUCKET_TYPE : integer := 6;
        MAX_BUCKET_SIZE : integer := 512;
        NUM_SUB_BUCKETS_BITS : integer := 7;
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
end GenericBucket;

architecture Bucket of GenericBucket is

component CoarseGrainedBucket is
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
end component;

component CoarseGrainedDistinctBucket is
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
end component;

component BloomFilterBucket is
    Generic (
        BUCKET_ID : integer := 0;
        NUM_HASHES : integer range 3 to 5 := 4;
        FILTER_SIZE_BITS : integer range 1 to 32 := 11
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

component CountingBloomFilterBucket is
    Generic (
        BUCKET_ID : integer := 0;
        NUM_HASHES : integer range 2 to 5 := 3;
        NUM_COUNTERS_BITS : integer range 1 to 32 := 10
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

component FineGrainedBucket is
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

begin

    fine_grained_inner : if BUCKET_TYPE = 0 generate
        fb : FineGrainedBucket 
            generic map (
                BUCKET_ID => BUCKET_ID,
                NUM_SUB_BUCKETS_BITS => NUM_SUB_BUCKETS_BITS
            )
            port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => s_axis_in_tvalid,
                s_axis_in_tready => s_axis_in_tready,
                s_axis_in_tdata => s_axis_in_tdata,
                s_axis_in_tdest => s_axis_in_tdest,
                m_axis_out_tvalid => m_axis_out_tvalid,
                m_axis_out_tready => m_axis_out_tready,
                m_axis_out_tdata => m_axis_out_tdata,
                m_axis_out_tdest => m_axis_out_tdest
            );
    end generate;
    
    
   coarse_grained_simple : if BUCKET_TYPE >= 1 and BUCKET_TYPE <= 3 generate
        cgs : CoarseGrainedBucket 
            generic map (
                BUCKET_ID => BUCKET_ID,
                BUCKET_TYPE => BUCKET_TYPE
            )
            port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => s_axis_in_tvalid,
                s_axis_in_tready => s_axis_in_tready,
                s_axis_in_tdata => s_axis_in_tdata,
                s_axis_in_tdest => s_axis_in_tdest,
                m_axis_out_tvalid => m_axis_out_tvalid,
                m_axis_out_tready => m_axis_out_tready,
                m_axis_out_tdata => m_axis_out_tdata,
                m_axis_out_tdest => m_axis_out_tdest
            );
    end generate;
    
    coarse_grained_distinct : if BUCKET_TYPE = 4 generate
        cgd : CoarseGrainedDistinctBucket 
            generic map (
                BUCKET_ID => BUCKET_ID,
                MAX_BUCKET_SIZE => MAX_BUCKET_SIZE
            )
            port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => s_axis_in_tvalid,
                s_axis_in_tready => s_axis_in_tready,
                s_axis_in_tdata => s_axis_in_tdata,
                s_axis_in_tdest => s_axis_in_tdest,
                m_axis_out_tvalid => m_axis_out_tvalid,
                m_axis_out_tready => m_axis_out_tready,
                m_axis_out_tdata => m_axis_out_tdata,
                m_axis_out_tdest => m_axis_out_tdest
            );
    end generate;
    
    coarse_grained_bloom : if BUCKET_TYPE = 5 generate
        cgb : BloomFilterBucket 
            generic map (
                BUCKET_ID => BUCKET_ID,
                NUM_HASHES => NUM_HASHES,
                FILTER_SIZE_BITS => FILTER_SIZE_BITS
            )
            port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => s_axis_in_tvalid,
                s_axis_in_tready => s_axis_in_tready,
                s_axis_in_tdata => s_axis_in_tdata,
                s_axis_in_tdest => s_axis_in_tdest,
                m_axis_out_tvalid => m_axis_out_tvalid,
                m_axis_out_tready => m_axis_out_tready,
                m_axis_out_tdata => m_axis_out_tdata,
                m_axis_out_tdest => m_axis_out_tdest
            );
    end generate;
    
    coarse_grained_counting_bloom : if BUCKET_TYPE = 6 generate
        cgb : CountingBloomFilterBucket 
            generic map (
                BUCKET_ID => BUCKET_ID,
                NUM_HASHES => NUM_HASHES,
                NUM_COUNTERS_BITS => FILTER_SIZE_BITS
            )
            port map (
                aclk => aclk,
                nrst => nrst,
                s_axis_in_tvalid => s_axis_in_tvalid,
                s_axis_in_tready => s_axis_in_tready,
                s_axis_in_tdata => s_axis_in_tdata,
                s_axis_in_tdest => s_axis_in_tdest,
                m_axis_out_tvalid => m_axis_out_tvalid,
                m_axis_out_tready => m_axis_out_tready,
                m_axis_out_tdata => m_axis_out_tdata,
                m_axis_out_tdest => m_axis_out_tdest
            );
    end generate;
    
    

end Bucket;
