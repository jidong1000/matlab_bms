project_root = fileparts(fileparts(mfilename('fullpath')));
raw_file = fullfile(project_root, 'datasets', ...
    'Panasonic 18650PF Data', 'Panasonic 18650PF Data', '25degC', ...
    'C20 OCV and 1C discharge tests_start_of_tests', ...
    '05-08-17_13.26 C20 OCV Test_C20_25dC.mat');
raw_data = load(raw_file, "meas");

raw_V = raw_data.meas.Voltage;
raw_Q = raw_data.meas.Ah;

rows = 7:1247;
C_20_V = raw_V(rows);
C_20_Q = raw_Q(rows);

discharge_Q = C_20_Q(1) - C_20_Q;
SOC = 1 - discharge_Q / discharge_Q(end);

SOC_list = flip(SOC);
OCV_list = flip(C_20_V);

plot(SOC_list * 100, OCV_list);
xlabel("SOC(%)");
ylabel("OCV(V)")
title("OCV-SOC")
