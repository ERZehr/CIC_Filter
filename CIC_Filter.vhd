library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.numeric_std.all;
    use IEEE.math_real.all;

entity CIC_Filter is
    generic (
        DEC_INTERP           : string  := "dec";
        R_RATE_FACTOR        : integer := 8;
        N_STAGES             : integer := 5;
        M_DIFFERENTIAL_DELAY : integer := 1;
        DATA_WIDTH           : integer := 16;
        RAM_RESOURCE         : string  := "registers";  -- growth
        DEBUG_ENABLED        : boolean := false
    );
    port (
        clk               : in  std_logic;
        reset_n           : in  std_logic;
        input_data_valid  : in  std_logic;
        input_data_I      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        input_data_Q      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        output_data_valid : out std_logic;
        output_data_I     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        output_data_Q     : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end CIC_Filter;

architecture rtl of CIC_Filter is

    constant BIT_GROWTH : integer := DATA_WIDTH + integer(ceil(real(N_STAGES) * log2(real(R_RATE_FACTOR * M_DIFFERENTIAL_DELAY))));
    constant PADDING    : integer := BIT_GROWTH - DATA_WIDTH;

    type ram_type is array (0 to N_STAGES - 1) of signed(BIT_GROWTH-1 downto 0);
    signal integrator_reg_I_d, integrator_reg_I_q, integrator_reg_Q_d, integrator_reg_Q_q         : ram_type := (others => (others => '0'));
    signal comb_reg_I_d, comb_reg_I_q, comb_reg_Q_d, comb_reg_Q_q                                 : ram_type := (others => (others => '0'));
    signal differential_reg_I_d, differential_reg_I_q, differential_reg_Q_d, differential_reg_Q_q : ram_type := (others => (others => '0'));
    signal output_data_I_d, output_data_Q_d                                                       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal output_data_valid_d                                                                    : std_logic;
    signal rate_counter_d, rate_counter_q                                                         : integer := 0;
    
    --attribute ram_style : string;
    --attribute ram_style of integrator_reg_I_d   : signal is RAM_RESOURCE;
    --attribute ram_style of integrator_reg_I_q   : signal is RAM_RESOURCE;
    --attribute ram_style of integrator_reg_Q_d   : signal is RAM_RESOURCE;
    --attribute ram_style of integrator_reg_Q_q   : signal is RAM_RESOURCE;
    --attribute ram_style of comb_reg_I_d         : signal is RAM_RESOURCE;
    --attribute ram_style of comb_reg_I_q         : signal is RAM_RESOURCE;
    --attribute ram_style of comb_reg_Q_d         : signal is RAM_RESOURCE;
    --attribute ram_style of comb_reg_Q_q         : signal is RAM_RESOURCE;
    --attribute ram_style of differential_reg_I_d : signal is RAM_RESOURCE;
    --attribute ram_style of differential_reg_I_q : signal is RAM_RESOURCE;
    --attribute ram_style of differential_reg_Q_d : signal is RAM_RESOURCE;
    --attribute ram_style of differential_reg_Q_q : signal is RAM_RESOURCE;

begin
    
    process(all)
    begin
        integrator_reg_I_d   <= integrator_reg_I_q;
        integrator_reg_Q_d   <= integrator_reg_Q_q;
        comb_reg_I_d         <= comb_reg_I_q; 
        comb_reg_Q_d         <= comb_reg_Q_q;
        differential_reg_I_d <= differential_reg_I_q;
        differential_reg_Q_d <= differential_reg_Q_q;
        rate_counter_d       <= rate_counter_q;
        output_data_I_d      <= output_data_I;
        output_data_Q_d      <= output_data_Q;
        output_data_valid_d  <= output_data_valid;
            
        if(reset_n = '0') then
            integrator_reg_I_d   <= (others => (others => '0'));
            integrator_reg_Q_d   <= (others => (others => '0'));
            comb_reg_I_d         <= (others => (others => '0'));
            comb_reg_Q_d         <= (others => (others => '0'));
            differential_reg_I_d <= (others => (others => '0'));
            differential_reg_Q_d <= (others => (others => '0'));
            rate_counter_d       <= 1;
            output_data_I_d      <= (others => '0');
            output_data_Q_d      <= (others => '0');
            output_data_valid_d  <= '0';
        else    
            if(input_data_valid = '1') then
                -- update integrators
                integrator_reg_I_d(0)     <= integrator_reg_I_q(0) + resize(signed(input_data_I), BIT_GROWTH);
                integrator_reg_Q_d(0)     <= integrator_reg_Q_q(0) + resize(signed(input_data_Q), BIT_GROWTH);
                for i in 1 to N_STAGES-1 loop
                    integrator_reg_I_d(i) <= integrator_reg_I_q(i) + integrator_reg_I_q(i - 1);
                    integrator_reg_Q_d(i) <= integrator_reg_Q_q(i) + integrator_reg_Q_q(i - 1);
                end loop;
                -- update combs
                if(rate_counter_q mod R_RATE_FACTOR = 0) then
                    rate_counter_d <= 1;
                    for i in 0 to N_STAGES-1 loop
                        if (i > 0) then
                            comb_reg_I_d(i)         <= comb_reg_I_q(i-1) - differential_reg_I_q(i);
                            comb_reg_Q_d(i)         <= comb_reg_Q_q(i-1) - differential_reg_Q_q(i);
                            differential_reg_I_d(i) <= comb_reg_I_q(i-1);
                            differential_reg_Q_d(i) <= comb_reg_Q_q(i-1);
                        else
                            comb_reg_I_d(i)         <= integrator_reg_I_q(N_STAGES-1) - differential_reg_I_q(i);
                            comb_reg_Q_d(i)         <= integrator_reg_Q_q(N_STAGES-1) - differential_reg_Q_q(i);
                            differential_reg_I_d(i) <= integrator_reg_I_q(N_STAGES-1);
                            differential_reg_Q_d(i) <= integrator_reg_Q_q(N_STAGES-1);
                        end if;
                    end loop;
                    output_data_I_d     <= std_logic_vector(resize(comb_reg_I_d(N_STAGES-1) / ((R_RATE_FACTOR * M_DIFFERENTIAL_DELAY) ** N_STAGES),DATA_WIDTH));
                    output_data_Q_d     <= std_logic_vector(resize(comb_reg_Q_d(N_STAGES-1) / ((R_RATE_FACTOR * M_DIFFERENTIAL_DELAY) ** N_STAGES),DATA_WIDTH));
                    output_data_valid_d <= '1';
                else
                    rate_counter_d <= rate_counter_q + 1;
                end if;
            else
                output_data_I_d     <= (others => '0');
                output_data_Q_d     <= (others => '0');
                output_data_valid_d <= '0';     
            end if;
        end if;
    end process;

    process(all)
    begin
        if(rising_edge(clk)) then
            integrator_reg_I_q   <= integrator_reg_I_d;
            integrator_reg_Q_q   <= integrator_reg_Q_d;
            comb_reg_I_q         <= comb_reg_I_d;
            comb_reg_Q_q         <= comb_reg_Q_d;
            differential_reg_I_q <= differential_reg_I_d;
            differential_reg_Q_q <= differential_reg_Q_d;
            rate_counter_q       <= rate_counter_d;
            output_data_I        <= output_data_I_d;
            output_data_Q        <= output_data_Q_d;
            output_data_valid    <= output_data_valid_d;
        end if;
    end process;

end rtl;
