file_pwd = "D:\project\matlab_project\BMS\RC1\HPPC_25C_full.csv";
T = readtable(file_pwd, 'Delimiter', ',');
T.Properties.VariableNames

I = -T.Current;
V = T.Voltage;
time = T.Time;

function U_p = polarization_voltage(I, Delta_t, R1, tau)
% 用实际采样间隔和每个区间起点的电流递推，初始极化电压为零。
    U_p = zeros(size(I));
    alpha = exp(-Delta_t / tau);
    for k = 1:numel(Delta_t)
        U_p(k + 1) = alpha(k) * U_p(k) + (1 - alpha(k)) * R1 * I(k);
    end
end
%% 辨识R0参数
R0_id = [1944, 2045];
R0_TMP = zeros(size(R0_id));
for i = 1:length(R0_id) 
    R0_TMP(i) = abs(V(R0_id(i)) - V(R0_id(i) + 1)) / abs(I(R0_id(i)) - I(R0_id(i) + 1));
end
R0 = mean(R0_TMP);
fprintf("R0 = %.4f\n", R0);

%% 用断流后的电压估算 B 和极化参数初值
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

% 初始OCV
B = p_fit(1);
% 初始极化电压
A = p_fit(2);
tau_initial = exp(p_fit(3));

Ip = mean(I(pulse_rows));
Tp = t_off - time(pulse_rows(1));
R1_initial = A / (Ip * (1 - exp(-Tp / tau_initial)));

%% 联合放电段和断流恢复段辨识R1和C1
replay_rows = (pulse_rows(1) - 3:rest_rows(end)).';
% 合并时间、电流和电压都相同的相邻记录，避免重复计入拟合误差。
keep = [true; diff(time(replay_rows)) ~= 0 | ...
    diff(I(replay_rows)) ~= 0 | diff(V(replay_rows)) ~= 0];
replay_rows = replay_rows(keep);
t_k = time(replay_rows);
I_k = I(replay_rows);
V_k = V(replay_rows);
Delta_t = diff(t_k);
relative_time = t_k - time(pulse_rows(1));

% 对处理后的记录进行分类，按照行号
pulse_mask = ismember(replay_rows, pulse_rows);
rest_mask = ismember(replay_rows, rest_rows);
% 计算两个阶段的权重
weights = zeros(size(V_k));
weights(pulse_mask) = 1 / nnz(pulse_mask);
weights(rest_mask) = 1 / nnz(rest_mask);

% 联合放电和静置两个阶段对R1和C1进行辨识
base_voltage = B - I_k * R0;
% 损失函数
joint_loss = @(trial) sum(weights .* (base_voltage - polarization_voltage(I_k, Delta_t, exp(trial(1)), exp(trial(2))) - V_k).^2);
joint_fit = fminsearch(joint_loss, log([R1_initial, tau_initial]), options);
R1 = exp(joint_fit(1));
tau = exp(joint_fit(2));
C1 = tau / R1;

fprintf('B = %.6f V\n', B);
fprintf('联合拟合: R1 = %.3f mOhm, tau = %.3f s, C1 = %.1f F\n', R1 * 1000, tau, C1);

%% 用实测电流计算极化电压
U_p = polarization_voltage(I_k, Delta_t, R1, tau);
figure;
plot(relative_time, U_p);
title("极化电压");
xlabel("时间 (s)");
ylabel("极化电压 (V)");

%% 画出仿真端电压和实测端电压的对比图
U_sim = base_voltage - U_p;
error_mV = (U_sim - V_k) * 1000;
fprintf('端电压 RMSE: 全窗口 %.2f mV, 放电 %.2f mV, 恢复 %.2f mV\n', ...
    sqrt(mean(error_mV.^2)), sqrt(mean(error_mV(pulse_mask).^2)), ...
    sqrt(mean(error_mV(rest_mask).^2)));
figure;
plot(relative_time, U_sim, 'blue');
hold on;
plot(relative_time, V_k, 'red');
hold off;
xlabel("时间 (s)");
ylabel("端电压 (V)");
legend("U_{sim}", "U_{real}");
