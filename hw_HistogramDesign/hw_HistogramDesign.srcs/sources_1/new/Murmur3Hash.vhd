library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Murmur3Hash is
    Port ( 
        seed : in STD_LOGIC_VECTOR(31 downto 0);
        key : in STD_LOGIC_VECTOR(31 downto 0);
        hash : out STD_LOGIC_VECTOR(31 downto 0)
    );
end Murmur3Hash;

architecture Behavioral of Murmur3Hash is

signal c1 : STD_ULOGIC_VECTOR(31 downto 0) := x"cc9e2d51";
signal c2 : STD_LOGIC_VECTOR(31 downto 0) := x"1b873593";
signal r1 : STD_LOGIC_VECTOR(31 downto 0) := x"0000000F";
signal r2 : STD_LOGIC_VECTOR(31 downto 0) := x"0000000D";
signal m : STD_LOGIC_VECTOR(31 downto 0) := x"00000005";
signal n : STD_LOGIC_VECTOR(31 downto 0) := x"e6546b64";


begin

    process(seed, key)
        variable k, h : unsigned(31 downto 0);
        variable km, hm : unsigned(63 downto 0);
    begin
        k := unsigned(key);
        
        -- murmur scramble
        km := k * unsigned(c1);
        k := km(31 downto 0);
        k := (k sll 15) or (k srl 17);
        km := k * unsigned(c2);
        k := km(31 downto 0);
        
        h := unsigned(seed);
        h := h xor k;
        h := (h sll 13) or (h srl 19);
        hm := h * unsigned(m); 
        h := hm(31 downto 0);
        h := h + unsigned(n);
        
        h := h xor x"00000004";
        h := h xor (h srl 16);
        hm := h * x"85ebca6b";
        h := hm(31 downto 0);
        h := h xor (h srl 13);
        hm := h * x"c2b2ae35";
        h := hm(31 downto 0);
        h := h xor (h srl 16);
        
        hash <= std_logic_vector(h);
    end process;

end Behavioral;
