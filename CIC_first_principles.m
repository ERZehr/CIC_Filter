%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Arbitrary CIC 
close all; clear; clc; fig_n = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Declare Input Paramters
R  = 12;       % Decimation factor
N  = 5;        % Number of stages
M  = 1;        % Differential delay

Fs_in = 1e5;   % Input sample rate
Bin = 16;      % input word length
B = Bin + ceil(N*log2(R*M)); % bit growth room

% Declare Input Signal
t = 0:1/Fs_in:1-1/Fs_in;
f_vec = [500]';
A_vec = [1]';
input_signal = [A_vec.*cos(2*pi*f_vec.*t)];
input_signal = fi(input_signal, 1, B, Bin-1, 'OverflowAction','Wrap', 'RoundingMethod','Floor');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot Input Signal
fig_n = stemplot(fig_n, t, input_signal, 'Input Signal', 'Time (s)', 'Magnitude');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Create and apply filter
integrator_reg = zeros(1,N);
comb_reg = zeros(1,N);

integrator_reg = fi(integrator_reg, 1, B, Bin-1, 'OverflowAction','Wrap', 'RoundingMethod','Floor');
comb_reg = fi(comb_reg, 1, B, Bin-1, 'OverflowAction','Wrap', 'RoundingMethod','Floor');

last_comb_reg = comb_reg; % for implementing M differential delay

output_signal = [];

for i = 1:length(input_signal)
    % shift in value
    input = input_signal(i);

    % update integrators
    integrator_reg(1) = integrator_reg(1) + input;
    for j = 2:N
        integrator_reg(j) = integrator_reg(j) + integrator_reg(j-1);
    end
    integrator_output = integrator_reg(N);

    % update combs
    if(mod(i, R)) == 0 % if this is a sample we are taking
        for j = 1:N
            if j > 1
                comb_reg(j) = comb_reg(j-1) - last_comb_reg(j);
                last_comb_reg(j) = comb_reg(j-1);
            else
                comb_reg(j) = integrator_output - last_comb_reg(j);
                last_comb_reg(j) = integrator_output;
            end
        end
        output_signal = [output_signal comb_reg(N)];
    end
end
output_signal = output_signal / (R*M)^N;
Fs_out = Fs_in / R;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot Output Signal
fig_n = stemplot(fig_n, 1:length(output_signal), output_signal, 'Output Signal', 'Index', 'Magnitude');


