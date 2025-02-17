library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FineGrainedBucket is
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
end FineGrainedBucket;

architecture Arch of FineGrainedBucket is

component xilinx_single_port_ram_read_first is
generic (
        RAM_WIDTH : integer := 32;                              -- Specify RAM data width
        RAM_DEPTH_BITS : integer := 10                        -- Specify RAM depth (number of address bits)
    );

port (
        addra : in std_logic_vector(RAM_DEPTH_BITS - 1 downto 0);                -- Address bus, width determined from RAM_DEPTH
        clka  : in std_logic;                                   -- Clock
        wea   : in std_logic;                                   -- Write enable
        ena   : in std_logic;                                   -- RAM Enable, for additional power savings, disable port when not in use
        douta : out std_logic_vector(RAM_WIDTH - 1 downto 0)   	-- RAM output data
    );
end component;

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

type state_type is (ST_IDLE, ST_READ, ST_READ_BRAM, ST_WRITE);
signal state : state_type := ST_IDLE;

constant NUM_SUB_BUCKETS : integer := 2 ** NUM_SUB_BUCKETS_BITS; -- RAM depth

signal high, low, addra, ram_data, ff_data, buf_ram_data : std_logic_vector(31 downto 0) := (others => '0');
signal data, buf_data : std_logic_vector(67 downto 0) := (others => '0');
signal is_configured, rst, data_valid, data_ready : std_logic := '0';
signal count : std_logic_vector(31 downto 0) := (others => '0');
signal msb_pos : natural := 0;
signal wea, ena, addr_in_ff : std_logic := '0';

type fast_forward_memory_type is array (0 to 3) of std_logic_vector(63 downto 0);
signal ff_mem : fast_forward_memory_type := (others => (others => '0'));

begin

    rst <= not nrst;

    relay : LatchedRelay generic map (WIDTH => 68)
        port map (
                clk => aclk,
                rst => rst,
                in_valid => data_valid,
                in_ready => data_ready,
                in_data => data,
                out_valid => m_axis_out_tvalid,
                out_ready => m_axis_out_tready,
                out_data => m_axis_out_tdata
        );
   
    process(aclk)
        variable next_pow2_var : std_logic_vector(31 downto 0) := (others => '0');
        --variable addr_in_ff : std_logic := '0';
    begin
        if rising_edge(aclk) then
            if nrst = '0' then
                state <= ST_IDLE;
                data_valid <= '0';
                wea <= '0';
                ena <= '0';
            else
                --addr_in_ff := '0';
                
                case state is
                    when ST_IDLE =>
                        
                        
                        if s_axis_in_tvalid = '1' and data_ready = '1' then
                            case s_axis_in_tdata(67 downto 64) is  
                                when "0000" =>
                                    -- noop
                                    state <= ST_IDLE;
                                    data <= s_axis_in_tdata;
                                    data_valid <= '1';
                                    wea <= '0';
                                    ena <= '0';
                                    
                                when "0001" =>
                                    -- config
                                    if is_configured = '0' then
                                        high <= s_axis_in_tdata(63 downto 32);
                                        low <= s_axis_in_tdata(31 downto 0);
                                        is_configured <= '1';
                                        data(67 downto 64) <= "0000";
                                        data(63 downto 0) <= s_axis_in_tdata(63 downto 0); 
                                        
                                        next_pow2_var := s_axis_in_tdata(63 downto 32) - s_axis_in_tdata(31 downto 0);
                                        next_pow2_var := next_pow2_var - 1;
                                        next_pow2_var := next_pow2_var or std_logic_vector(unsigned(next_pow2_var) srl 1);
                                        next_pow2_var := next_pow2_var or std_logic_vector(unsigned(next_pow2_var) srl 2);
                                        next_pow2_var := next_pow2_var or std_logic_vector(unsigned(next_pow2_var) srl 4);
                                        next_pow2_var := next_pow2_var or std_logic_vector(unsigned(next_pow2_var) srl 8);
                                        next_pow2_var := next_pow2_var or std_logic_vector(unsigned(next_pow2_var) srl 16);
                                        next_pow2_var := next_pow2_var + 1;
                                        
                                        for i in 0 to 31 loop
                                            if next_pow2_var(i) = '1' then
                                                msb_pos <= i;
                                                exit;
                                            end if;
                                        end loop; 
                                    else
                                        data <= s_axis_in_tdata;
                                    end if;
                                    
                                    state <= ST_IDLE;
                                    data_valid <= '1';
                                    wea <= '0';
                                    ena <= '0';
                                    
                                when "0010" =>
                                    -- update
                                    buf_data <= s_axis_in_tdata;
                                    addra <= std_logic_vector(unsigned(s_axis_in_tdata(31 downto 0) - low) srl (msb_pos - NUM_SUB_BUCKETS_BITS));
                                    
                                    for i in 0 to 3 loop
                                        if ff_mem(i)(63 downto 32) = std_logic_vector(unsigned(s_axis_in_tdata(31 downto 0) - low) srl (msb_pos - NUM_SUB_BUCKETS_BITS)) then
                                            addr_in_ff <= '1';
                                            ff_data <= ff_mem(i)(31 downto 0);
                                            data(63 downto 32) <= ff_mem(i)(31 downto 0);
                                            exit;
                                        else
                                            addr_in_ff <= '0';
                                        end if;
                                    end loop;
                                    
--                                    if addr_in_ff = '1' then
--                                        state <= ST_READ;
--                                    else
--                                        state <= ST_READ;
--                                    end if;
                                    
                                    state <= ST_READ;
                                    
                                    data(67 downto 64) <= s_axis_in_tdata(67 downto 64);
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                    data_valid <= '0';
                                    ena <= '1';
                                    wea <= '0';
                                    
                                when "0011" =>
                                    -- read
                                    buf_data <= s_axis_in_tdata;
                                    addra <= std_logic_vector(unsigned(s_axis_in_tdata(31 downto 0) - low) srl (msb_pos - NUM_SUB_BUCKETS_BITS));
                                    
                                    for i in 0 to 3 loop
                                        if ff_mem(i)(63 downto 32) = std_logic_vector(unsigned(s_axis_in_tdata(31 downto 0) - low) srl (msb_pos - NUM_SUB_BUCKETS_BITS)) then
                                            addr_in_ff <= '1';
                                            ff_data <= ff_mem(i)(31 downto 0);
                                            data(63 downto 32) <= ff_mem(i)(31 downto 0);
                                            exit;
                                        else
                                            addr_in_ff <= '0';
                                        end if;
                                    end loop;
                                    
                                    
                                    state <= ST_READ;
                                    data_valid <= '0';
                                    
--                                    if addr_in_ff = '1' then
--                                        state <= ST_IDLE;
--                                        data_valid <= '1'; 
--                                    else
--                                        state <= ST_READ;
--                                        data_valid <= '0';
--                                    end if;
                                    
                                    data(31 downto 0) <= s_axis_in_tdata(31 downto 0);
                                    ena <= '1';
                                    wea <= '0';
                                    
                                when others =>
                                    state <= ST_IDLE;
                                    data <= s_axis_in_tdata;
                                    data_valid <= '0';
                                    wea <= '0';
                                    ena <= '0';
                            end case;
                        end if;
                    
                    when ST_READ =>
                        case buf_data(67 downto 64) is
                            when "0010" => 
                                if addr_in_ff = '1' then
                                    data(63 downto 32) <= ff_data + 1;
                                    buf_ram_data <= ff_data + 1;
                                    state <= ST_WRITE;
                                    data_valid <= '1';
                                else 
--                                    data(63 downto 32) <= ram_data + 1;
--                                    buf_ram_data <= ram_data + 1;
                                    state <= ST_READ_BRAM;
                                    
                                end if;
                                
                                
                            when "0011" =>
                                if addr_in_ff = '1' then
                                    data(63 downto 32) <= ff_data;
                                    buf_ram_data <= ff_data;
                                    state <= ST_IDLE;
                                    data_valid <= '1';
                                    ena <= '0';
                                else 
--                                    data(63 downto 32) <= ram_data + 1;
--                                    buf_ram_data <= ram_data + 1;
                                    state <= ST_READ_BRAM;
                                    
                                end if;
                                
                                --data(63 downto 32) <= ram_data;

                                
                            when others =>
                                null;
                        end case;
                        
                        addr_in_ff <= '0';
--                        data_valid <= '1';
                        data(67 downto 64) <= buf_data(67 downto 64);
                    
                    when ST_READ_BRAM =>
                        case buf_data(67 downto 64) is
                            when "0010" => 
                                
                                data(63 downto 32) <= ram_data + 1;
                                buf_ram_data <= ram_data + 1;
                                state <= ST_WRITE;
                                data_valid <= '1';

                                
                                
                            when "0011" =>
                                data(63 downto 32) <= ram_data;
                                buf_ram_data <= ram_data ;
                                state <= ST_IDLE;
                                data_valid <= '1';
                                ena <= '0';
                                
                            when others =>
                                null;
                        end case;
                        
                        data(67 downto 64) <= buf_data(67 downto 64);
                    
                    when ST_WRITE =>
                        
                        ff_mem(3) <= ff_mem(2);
                        ff_mem(2) <= ff_mem(1);
                        ff_mem(1) <= ff_mem(0);
                        ff_mem(0) <= addra & buf_ram_data;
                        
                        state <= ST_IDLE;
                        data_valid <= '0';
                        --data(63 downto 32) <= buf_ram_data;
                        ena <= '1';
                        wea <= '1';
                    
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
    ram : xilinx_single_port_ram_read_first generic map (RAM_DEPTH_BITS => NUM_SUB_BUCKETS_BITS)
        port map (
            addra => addra(NUM_SUB_BUCKETS_BITS - 1 downto 0),
            clka => aclk, 
            wea => wea,
            ena => ena,
            douta => ram_data
        );

    s_axis_in_tready <= data_ready when state = ST_IDLE and nrst = '1' else '0';

end Arch;
