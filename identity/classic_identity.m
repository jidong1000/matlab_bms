file_pwd = fullfile(fileparts(mfilename('fullpath')), 'HPPC_25C_full.csv');
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

%% 用断流恢复段最小二乘辨识
pulse_rows = 1945:2045;
rest_rows = 2046:2345;

% 脉冲持续时间
Tp = time(rest_rows(1)) - time(pulse_rows(1));
% 放电电流幅值
Ip = mean(I(pulse_rows));
% 以断流时刻为零时刻
tr = time(rest_rows) - time(rest_rows(1));
vr = V(rest_rows);
% 设置辨识初值
v_ref = vr(end);
y = 1000 * (vr - v_ref);
A0 = max(y(end) - y(1), 0.001);
tau0 = (tr(end) - tr(1)) / 3;
% 构建模型
% p(1):V_infinity
% p(2):A
% p(3):tau
model = @(p) p(1) - exp(p(2)) .* exp(-tr / exp(p(3)));
% 损失函数
loss = @(p) sum((y - model(p)) .^2);
% 初值
p0 = [0, log(A0), log(tau0)];
opts = optimset('Display', 'off', 'TolX', 1e-8, 'TolFun', 1e-8);
params = fminsearch(loss, p0, opts);

V_infinity = v_ref + params(1) / 1000;
A = exp(params(2)) / 1000;
tau = exp(params(3));

R1 = A / (Ip * (-expm1(-Tp / tau)));
C1 = tau / R1;
fprintf("A:%.6f, tau:%.6f, R1:%.6f, C1:%.6f\n", A, tau, R1, C1);

%% 画出拟合曲线和实测对比图
idx_start = pulse_rows(1) - 10;
idx = idx_start:rest_rows(end);

ts = time(idx);
Us = V(idx);
Is = I(idx);
Delta_t = diff(ts);
U_p = polarization_voltage(Is, Delta_t, R1, tau);

U_sim = V_infinity - R0 .* Is - U_p;
rmse = sqrt(mean(((U_sim - Us) * 1000) .^ 2));
fprintf("端电压rmse:%.3f mV", rmse);
plot(ts, U_sim, "red");
hold on;
plot(ts, Us, 'blue');
hold off;
legend("fit", "measured", "Location", "best");
ylabel("端电压");
grid on;
