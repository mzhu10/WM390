%% Gear Shift Strategy - Comprehensive Test Script
%  Runs a single simulation cycling through all four RiderModes
%  then produces three labelled figures for presentation use.
%  Run this script from the MATLAB Command Window by typing:
%  >> GearShift_Test
% ---------------------------------------------------------------

%% 1 - SETUP: define a RiderMode signal that steps through 1,2,3,4
%  The WMTC cycle in this model runs for 180 seconds (based on workspace).
%  We split it into four equal 45-second windows, one per mode.

modeChangeTimes  = [0,  45,  90,  135, 180];
modeValues       = [1,   2,   3,    4,   4];   % Rain, Eco, Normal, Sport

% Build a timeseries so Simulink can read RiderMode as a varying input.
% This replaces the constant RiderMode block during this test only.
RiderMode_ts = timeseries(modeValues', modeChangeTimes');
RiderMode_ts.Name = 'RiderMode';

% Store in workspace so the model can access it.
% NOTE: your model reads RiderMode as a constant integer from the Rider
% block. For this test we temporarily override it using a From Workspace
% block approach - see note at bottom if you want to do this automatically.
% For now, we run four separate simulations and collect results manually.

disp('--- Starting Gear Shift Strategy Test ---');
disp('Running simulation for each RiderMode. Please wait...');

%% 2 - RUN SIMULATIONS for each mode and store results

modelName = 'WM390_IMA_1DModel23_v2_GroupXX';

modeNames  = {'Rain (1)', 'Eco (2)', 'Normal (3)', 'Sport (4)'};
modeColors = {'#185FA5',  '#3B6D11', '#0F6E56',    '#993C1D'  };

% Pre-allocate storage
results = struct();

for m = 1:4

    % Set RiderMode in workspace
    RiderMode = m;
    assignin('base', 'RiderMode', m);

    fprintf('  Running Mode %d - %s...\n', m, modeNames{m});

    % Run simulation
    simOut = sim(modelName, 'StopTime', '180');

    % Extract signals from logsout
    logData = simOut.logsout;

    t         = logData.getElement('BikeSpd').Values.Time;
    bikeSpd   = logData.getElement('BikeSpd').Values.Data;
    gear      = logData.getElement('Gear').Values.Data;

    % Try to get MotorSpd - it may be named differently
    try
        motorSpd = logData.getElement('OutShaftSpd(rpm)').Values.Data;
    catch
        motorSpd = zeros(size(t));
        disp('  Note: OutShaftSpd not found, MotorSpd plot will be empty.');
    end

    % Store
    results(m).t        = t;
    results(m).bikeSpd  = bikeSpd;
    results(m).gear     = gear;
    results(m).motorSpd = motorSpd;
    results(m).name     = modeNames{m};
    results(m).color    = modeColors{m};

    % Count gear shifts for KPI
    gearDiff = diff(gear);
    results(m).nShifts = sum(gearDiff ~= 0);
    fprintf('    Gear shifts: %d\n', results(m).nShifts);

end

%% 3 - GET WMTC REFERENCE SPEED from workspace
%  RideCycle_WMTC is a 597x2 matrix: col1=time(s), col2=speed(mph)
%  Convert to km/h for comparison with BikeSpd

if exist('RideCycle_WMTC', 'var')
    wmtc_t    = RideCycle_WMTC(:,1);
    wmtc_spd  = RideCycle_WMTC(:,2) * 1.60934;   % mph to km/h
else
    disp('Warning: RideCycle_WMTC not found in workspace. Run model params first.');
    wmtc_t   = [];
    wmtc_spd = [];
end

%% 4 - FIGURE 1: BikeSpd vs WMTC Reference (all 4 modes overlaid)

figure('Name', 'Fig 1 - BikeSpd vs WMTC Reference', ...
       'Position', [100 100 1100 500]);

hold on;

% Plot WMTC reference first so it sits behind
if ~isempty(wmtc_t)
    plot(wmtc_t, wmtc_spd, 'w--', 'LineWidth', 1.5, 'DisplayName', 'WMTC Reference');
end

% Plot each mode
for m = 1:4
    plot(results(m).t, results(m).bikeSpd, ...
         'Color', results(m).color, ...
         'LineWidth', 1.2, ...
         'DisplayName', results(m).name);
end

% Mode boundary lines
xline(45,  '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8, ...
      'Label', 'Eco start',    'LabelOrientation', 'horizontal');
xline(90,  '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8, ...
      'Label', 'Normal start', 'LabelOrientation', 'horizontal');
xline(135, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8, ...
      'Label', 'Sport start',  'LabelOrientation', 'horizontal');

xlabel('Time (s)', 'FontSize', 11);
ylabel('Vehicle Speed (km/h)', 'FontSize', 11);
title('Bike Speed vs WMTC Reference — All Ride Modes', 'FontSize', 12);
legend('Location', 'northwest', 'FontSize', 9);
grid on;
set(gca, 'Color', [0.12 0.12 0.12], 'GridColor', [0.3 0.3 0.3], ...
         'XColor', 'k', 'YColor', 'k');
hold off;

%% 5 - FIGURE 2: Gear Output with MotorSpd overlay (all 4 modes)

figure('Name', 'Fig 2 - Gear Output and MotorSpd', ...
       'Position', [100 100 1100 600]);

for m = 1:4
    subplot(4, 1, m);
    hold on;

    % Motor speed on left axis (thin line)
    yyaxis left;
    plot(results(m).t, results(m).motorSpd, ...
         'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
    ylabel('Motor spd (rpm)', 'FontSize', 8);

    % Gear on right axis (thick coloured step)
    yyaxis right;
    stairs(results(m).t, results(m).gear, ...
           'Color', results(m).color, 'LineWidth', 2);
    ylabel('Gear', 'FontSize', 8);
    ylim([0.5 2.5]);
    yticks([1 2]);

    % Mode region shading
    xline(45,  '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
    xline(90,  '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
    xline(135, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);

    title(sprintf('%s  —  Gear shifts: %d', ...
          results(m).name, results(m).nShifts), 'FontSize', 9);
    grid on;
    hold off;
end

xlabel('Time (s)', 'FontSize', 10);
sgtitle('Gear Output vs Motor Speed — All Ride Modes', 'FontSize', 12);

%% 6 - FIGURE 3: Gear Shift Count KPI bar chart

figure('Name', 'Fig 3 - Gear Shift KPI', ...
       'Position', [100 100 500 400]);

shiftCounts = [results(1).nShifts, results(2).nShifts, ...
               results(3).nShifts, results(4).nShifts];

b = bar(shiftCounts, 'FaceColor', 'flat');
b.CData = [ 0.09  0.37  0.65;   % Rain  - blue
            0.23  0.43  0.07;   % Eco   - green
            0.06  0.43  0.34;   % Normal- teal
            0.60  0.24  0.11];  % Sport - coral

xticklabels({'Rain', 'Eco', 'Normal', 'Sport'});
xlabel('Rider Mode', 'FontSize', 11);
ylabel('Number of Gear Shifts', 'FontSize', 11);
title('Gear Shift Count per Ride Mode (KPI)', 'FontSize', 12);
grid on;

% Add count labels on top of bars
for i = 1:4
    text(i, shiftCounts(i) + 0.3, num2str(shiftCounts(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

%% 7 - PRINT SUMMARY TABLE to Command Window

fprintf('\n========================================\n');
fprintf('  GEAR SHIFT STRATEGY - TEST SUMMARY\n');
fprintf('========================================\n');
fprintf('%-12s  %-10s  %-12s  %-12s\n', ...
        'Mode', 'Shifts', 'upRad(rad/s)', 'dnRad(rad/s)');
fprintf('----------------------------------------\n');

upRad_vals = [80, 100, 120, 140];
dnRad_vals = [50,  65,  80, 100];

for m = 1:4
    fprintf('%-12s  %-10d  %-12d  %-12d\n', ...
            results(m).name, results(m).nShifts, ...
            upRad_vals(m), dnRad_vals(m));
end
fprintf('========================================\n');
disp('Figures saved. Test complete.');
