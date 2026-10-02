library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    use IEEE.MATH_REAL.ALL;

entity CIC_Filter_tb is
end CIC_Filter_tb;

architecture sim of CIC_Filter_tb is

    -- Must match the DUT generics
    constant DEC_INTERP           : string  := "dec";
    constant R_RATE_FACTOR        : integer := 8;
    constant N_STAGES             : integer := 5;
    constant M_DIFFERENTIAL_DELAY : integer := 1;
    constant DATA_WIDTH           : integer := 16;
    constant CLK_PERIOD           : time    := 10 ns;

    -- Test tone settings (frequencies are in cycles per input sample)
    constant AMPLITUDE   : real    := 20000.0;
    constant F_PASS      : real    := 0.01;   -- well inside the passband
    constant F_STOP      : real    := 0.20;   -- in the stopband (should be attenuated)
    constant N_SAMPLES   : integer := 600;    -- samples per phase
    constant SETTLE_SAMP : integer := 100;    -- ignore transient before measuring peaks

    signal clk               : std_logic := '0';
    signal reset_n           : std_logic := '0';
    signal input_data_valid  : std_logic := '0';
    signal input_data_I      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal input_data_Q      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal output_data_valid : std_logic;
    signal output_data_I     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal output_data_Q     : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal clear_peak : std_logic := '0';
    signal peak_I     : integer   := 0;
    signal peak_Q     : integer   := 0;
    signal sim_done   : boolean   := false;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    -- Device under test
    dut : entity work.CIC_Filter
        generic map (
            DEC_INTERP           => DEC_INTERP,
            R_RATE_FACTOR        => R_RATE_FACTOR,
            N_STAGES             => N_STAGES,
            M_DIFFERENTIAL_DELAY => M_DIFFERENTIAL_DELAY,
            DATA_WIDTH           => DATA_WIDTH,
            RAM_RESOURCE         => "registers"
        )
        port map (
            clk               => clk,
            reset_n           => reset_n,
            input_data_valid  => input_data_valid,
            input_data_I      => input_data_I,
            input_data_Q      => input_data_Q,
            output_data_valid => output_data_valid,
            output_data_I     => output_data_I,
            output_data_Q     => output_data_Q
        );

    -- Stimulus: complex tone  I = A*cos(phase), Q = A*sin(phase)
    stim : process
        variable phase : real := 0.0;

        -- Drive one tone for N_SAMPLES samples
        procedure run_tone(freq : real) is
        begin
            clear_peak <= '1';
            for n in 0 to N_SAMPLES-1 loop
                input_data_valid <= '1';
                input_data_I <= std_logic_vector(to_signed(integer(round(AMPLITUDE * cos(phase))), DATA_WIDTH));
                input_data_Q <= std_logic_vector(to_signed(integer(round(AMPLITUDE * sin(phase))), DATA_WIDTH));
                phase := phase + MATH_2_PI * freq;
                if phase > MATH_2_PI then
                    phase := phase - MATH_2_PI;
                end if;
                wait until rising_edge(clk);
                if n = SETTLE_SAMP then
                    clear_peak <= '0';   -- start peak measurement after the transient
                end if;
                
                wait until rising_edge(clk);
                input_data_valid <= '0';
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                
            end loop;
        end procedure;
    begin
        -- Reset
        reset_n          <= '0';
        input_data_valid <= '0';
        wait for 5 * CLK_PERIOD;
        wait until rising_edge(clk);
        reset_n <= '1';
        wait until rising_edge(clk);

        -- Phase 1: passband tone
        report "Phase 1: passband tone, f = " & real'image(F_PASS) & " cycles/sample";
        run_tone(F_PASS);
        wait for CLK_PERIOD;
        report "  Phase 1 peak output  I=" & integer'image(peak_I) &
               "  Q=" & integer'image(peak_Q) &
               "  (input amplitude = " & integer'image(integer(AMPLITUDE)) & ")";

        -- Phase 2: stopband tone
        report "Phase 2: stopband tone, f = " & real'image(F_STOP) & " cycles/sample";
        run_tone(F_STOP);
        wait for CLK_PERIOD;
        report "  Phase 2 peak output  I=" & integer'image(peak_I) &
               "  Q=" & integer'image(peak_Q) &
               "  (should be much smaller than phase 1)";

        -- Idle
        input_data_valid <= '0';
        for n in 0 to 19 loop
            wait until rising_edge(clk);
        end loop;

        sim_done <= true;
        report "Simulation finished";
        wait;
    end process;

    -- Monitor: print valid outputs and track peak magnitude
    monitor : process(clk)
        variable vi, vq : integer;
    begin
        if rising_edge(clk) then
            if clear_peak = '1' then
                peak_I <= 0;
                peak_Q <= 0;
            end if;
            if output_data_valid = '1' then
                vi := to_integer(signed(output_data_I));
                vq := to_integer(signed(output_data_Q));
                report "t=" & time'image(now) &
                       "  I=" & integer'image(vi) &
                       "  Q=" & integer'image(vq);
                if clear_peak = '0' then
                    if abs(vi) > peak_I then peak_I <= abs(vi); end if;
                    if abs(vq) > peak_Q then peak_Q <= abs(vq); end if;
                end if;
            end if;
        end if;
    end process;

end sim;
