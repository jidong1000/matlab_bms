file_pwd = "D:\project\matlab_project\BMS\RC1\HPPC_25C_full.csv";
T = readtable(file_pwd, 'Delimiter', ',');
T.Properties.VariableNames

I = -T.Current;
V = T.Voltage;
time = T.Time;

%% 辨识R0参数
R0_id = [1944, 2045];
R0_TMP = zeros(size(R0_id));
for i = 1:length(R0_id) 
    R0_TMP(i) = abs(V(R0_id(i)) - V(R0_id(i) + 1)) / abs(I(R0_id(i)) - I(R0_id(i) + 1));
end
R0 = mean(R0_TMP);
fprintf("R0 = %.4f\n", R0);

%% 用断流后的电压辨识 R1 和 C1
pulse_rows = 1945:2045;
rest_rows = 2046:2345;
t_off = time(rest_rows(1));
% 定义新变量，以断流后的第一采样时刻为零时刻
s = time(rest_rows) - t_off;
rest_voltage = V(rest_rows);

% 参数 params = [B, A, log(tau)]，用 exp(params(3)) 保证 tau 为正。
voltage_model = @(params) params(1) - params(2) * exp(-s / exp(params(3)));
loss = @(trial) sum((rest_voltage - voltage_model(trial)) .^ 2);
% 最小二乘法的初值
p0 = [rest_voltage(end), rest_voltage(end) - rest_voltage(1), log(5)];
options = optimset('TolX', 1e-9, 'TolFun', 1e-12);
% 进行迭代辨识
p_fit = fminsearch(loss, p0, options);

B = p_fit(1);
A = p_fit(2);
tau = exp(p_fit(3));

Ip = mean(I(pulse_rows));
Tp = t_off - time(pulse_rows(1));
R1 = A / (Ip * (1 - exp(-Tp / tau)));
C1 = tau / R1;

fprintf('B = %.6f V, A = %.3f mV, tau = %.3f s\n', B, A * 1000, tau);
fprintf('R1 = %.3f mOhm, C1 = %.1f F\n', R1 * 1000, C1);