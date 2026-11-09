Q = 3;
R0 = 0.03;
R1 = 0.02;
C1 = 2000;
dt = 1;
inpulse = 2;

SOC_list = [0, 0.1, 0.2, 0.4, 0.6, 0.8, 1.0];
OCV_list = [3.00, 3.35, 3.50, 3.65, 3.78, 3.96, 4.20];

t = 0:dt:240;
I = zeros(size(t));
% 第20秒接通负载（放电为正），第80秒断开
I(t >= 20 & t < 80) = inpulse;

% 设置初始值
SOC = zeros(size(t));
SOC(1) = 0.8;
U_p = zeros(size(t));
U_p(1) = 0;
tau = R1 * C1;
alpha = exp(-dt / tau);

% 安时积分计算
for k = 1:numel(t) - 1
    SOC(k + 1) = SOC(k) - I(k) * dt / (3600 * Q);
    U_p(k + 1) = alpha * U_p(k) + (1 - alpha) * R1 * I(k);
end

% 通过插值函数拟合曲线，再输入SOC查表计算出OCV的值
OCV = interp1(SOC_list, OCV_list, SOC, "linear");
U_t = OCV - I * R0 - U_p;

subplot(3, 1, 1);
stairs(t, I, LineWidth=1.4);
ylabel('电流（A）');
grid on;

subplot(3, 1, 2);
plot(t, U_t, LineWidth=1.4);
hold on;
plot(t, OCV, '--', LineWidth=1.2);
hold off;
ylabel('电压（V）');
legend('端电压', '开路电压OCV', Location='best');
grid on;

subplot(3, 1, 3);
plot(t, SOC * 100, LineWidth=1.4);
ylabel('SOC（%）');
grid on;