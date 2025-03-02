library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.fpu_pkg.all;
use work.component_pkg.all;

-- floating point multiplication in 11 cycles after start signal falls (if the start signal remains HIGH, the multiplication will not start)
entity fp_mul is
    port (
        clk_i 			: in std_logic;
        start_i         : in std_logic;

        -- Input Operands A & B
        opa_i        	: in std_logic_vector(31 downto 0); 
        opb_i           : in std_logic_vector(31 downto 0);
        
        -- Output port
        output_o        : out std_logic_vector(31 downto 0);
        
        -- Exceptions
        ine_o 			: out std_logic; -- inexact
        overflow_o  	: out std_logic; -- overflow
        underflow_o 	: out std_logic; -- underflow
        inf_o			: out std_logic; -- infinity
        zero_o			: out std_logic; -- zero
        qnan_o			: out std_logic; -- queit Not-a-Number
        snan_o			: out std_logic -- signaling Not-a-Number
	);   
end fp_mul;


-- Asynchronous inputs, Asynchronous outputs
architecture round_to_nearest_even_parallel of fp_mul is
	
	signal pre_norm_mul_exp_10: std_logic_vector(9 downto 0);
	signal pre_norm_mul_fracta_24: std_logic_vector(23 downto 0);
	signal pre_norm_mul_fractb_24: std_logic_vector(23 downto 0);
	 	
	signal mul_24_fract_48: std_logic_vector(47 downto 0);
	signal mul_24_sign: std_logic;
	signal serial_mul_fract_48: std_logic_vector(47 downto 0);
	signal serial_mul_sign: std_logic;
	
	signal mul_fract_48: std_logic_vector(47 downto 0);
	signal mul_sign: std_logic;
	
	signal post_norm_mul_output: std_logic_vector(31 downto 0);
	signal post_norm_mul_ine: std_logic;
	signal s_output_o: std_logic_vector(31 downto 0); -- outputs cannot be read
    
    -- Exception signals
    signal s_qnan_o, s_snan_o: std_logic;

begin

    i_pre_norm_mul: pre_norm_mul
        port map(
            clk_i       => clk_i,     
            opa_i       => opa_i,
            opb_i       => opb_i,
            exp_10_o    => pre_norm_mul_exp_10,
            fracta_24_o => pre_norm_mul_fracta_24,
            fractb_24_o => pre_norm_mul_fractb_24
        );
                
    i_mul_24 : mul_24
        port map(
            clk_i    => clk_i,
            fracta_i => pre_norm_mul_fracta_24,
            fractb_i => pre_norm_mul_fractb_24,
            signa_i  => opa_i(31),
            signb_i  => opb_i(31),
            start_i  => start_i,
            fract_o  => mul_24_fract_48, 
            sign_o   =>   mul_24_sign,
            ready_o  => open
        );  
    
    i_post_norm_mul : post_norm_mul
        port map(
            clk_i      => clk_i,
            opa_i      => opa_i,
            opb_i      => opb_i,
            exp_10_i   => pre_norm_mul_exp_10,
            fract_48_i => mul_24_fract_48,
            sign_i     => mul_24_sign,
            rmode_i    => "00",
            output_o   => s_output_o,
            ine_o      => post_norm_mul_ine
        );
             
    -- Generate Exceptions 
	underflow_o <= '1' when s_output_o(30 downto 23)="00000000" and post_norm_mul_ine='1' else '0'; 
	overflow_o <= '1' when s_output_o(30 downto 23)="11111111" and post_norm_mul_ine='1' else '0';
	inf_o <= '1' when s_output_o(30 downto 23)="11111111" and (s_qnan_o or s_snan_o)='0' else '0';
	zero_o <= '1' when or_reduce(s_output_o(30 downto 0))='0' else '0';
	s_qnan_o <= '1' when s_output_o(30 downto 0)=QNAN else '0';
    s_snan_o <= '1' when opa_i(30 downto 0)=SNAN or opb_i(30 downto 0)=SNAN else '0';

   -- outputs
   qnan_o <= s_qnan_o;
   snan_o <= s_snan_o;
   ine_o <= post_norm_mul_ine;
   output_o <= s_output_o;

end architecture round_to_nearest_even_parallel;


-- Asynchronous inputs, Synchronous outputs
architecture round_to_nearest_even_parallel_syncOut of fp_mul is
    
    signal pre_norm_mul_exp_10: std_logic_vector(9 downto 0);
    signal pre_norm_mul_fracta_24: std_logic_vector(23 downto 0);
    signal pre_norm_mul_fractb_24: std_logic_vector(23 downto 0);
        
    signal mul_24_fract_48: std_logic_vector(47 downto 0);
    signal mul_24_sign: std_logic;
    signal serial_mul_fract_48: std_logic_vector(47 downto 0);
    signal serial_mul_sign: std_logic;
    
    signal mul_fract_48: std_logic_vector(47 downto 0);
    signal mul_sign: std_logic;
    
    signal post_norm_mul_output: std_logic_vector(31 downto 0);
    signal post_norm_mul_ine: std_logic;
    signal s_output_o: std_logic_vector(31 downto 0); -- outputs cannot be read
    
    -- Exception signals
    signal s_underflow_o, s_overflow_o, s_inf_o, s_zero_o, s_qnan_o, s_snan_o: std_logic;

begin

    i_pre_norm_mul: pre_norm_mul
        port map(
            clk_i       => clk_i,     
            opa_i       => opa_i,
            opb_i       => opb_i,
            exp_10_o    => pre_norm_mul_exp_10,
            fracta_24_o => pre_norm_mul_fracta_24,
            fractb_24_o => pre_norm_mul_fractb_24
        );
                
    i_mul_24 : mul_24
        port map(
            clk_i    => clk_i,
            fracta_i => pre_norm_mul_fracta_24,
            fractb_i => pre_norm_mul_fractb_24,
            signa_i  => opa_i(31),
            signb_i  => opb_i(31),
            start_i  => start_i,
            fract_o  => mul_24_fract_48, 
            sign_o   =>   mul_24_sign,
            ready_o  => open
        );  
    
    i_post_norm_mul : post_norm_mul
        port map(
            clk_i      => clk_i,
            opa_i      => opa_i,
            opb_i      => opb_i,
            exp_10_i   => pre_norm_mul_exp_10,
            fract_48_i => mul_24_fract_48,
            sign_i     => mul_24_sign,
            rmode_i    => "00",
            output_o   => s_output_o,
            ine_o      => post_norm_mul_ine
        );
             
    -- Generate Exceptions 
    s_underflow_o <= '1' when s_output_o(30 downto 23)="00000000" and post_norm_mul_ine='1' else '0'; 
    s_overflow_o <= '1' when s_output_o(30 downto 23)="11111111" and post_norm_mul_ine='1' else '0';
    s_inf_o <= '1' when s_output_o(30 downto 23)="11111111" and (s_qnan_o or s_snan_o)='0' else '0';
    s_zero_o <= '1' when or_reduce(s_output_o(30 downto 0))='0' else '0';
    s_qnan_o <= '1' when s_output_o(30 downto 0)=QNAN else '0';
    s_snan_o <= '1' when opa_i(30 downto 0)=SNAN or opb_i(30 downto 0)=SNAN else '0';

    -- Output registers
    process(clk_i) begin

        if rising_edge(clk_i) then

            underflow_o <= s_underflow_o;
            overflow_o <= s_overflow_o;
            inf_o <= s_inf_o;
            ine_o <= post_norm_mul_ine;
            zero_o <= s_zero_o;
            qnan_o <= s_qnan_o;
            snan_o <= s_snan_o;
            output_o <= s_output_o;

        end if;

    end process;

   --qnan_o <= s_qnan_o;
   --snan_o <= s_snan_o;
   --ine_o <= post_norm_mul_ine;
   --output_o <= s_output_o;

end architecture round_to_nearest_even_parallel_syncOut;