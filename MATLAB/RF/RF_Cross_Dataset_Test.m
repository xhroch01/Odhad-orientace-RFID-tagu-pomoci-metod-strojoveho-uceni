% Skript načítá natrénovaný RF model z dat lambda/3 a 
% provede test na datasetu s jiným rozestupem sond (lambda/2 nebo lambda/4)
% který model během tréninku nikdy neviděl.

clear; 
clc; 
close all;

%% Načtení RF modelu a neznámého datasetu

% Načtení RF modelu
load('RF_Model.mat', 'RFmodel'); 

% Načtení dat
csvFile = 'Results_RF_data_lambda2.csv'; 

csvData = readtable(csvFile);
numTestSamples  = height(csvData);

fprintf('Celkový počet pozic: %d\n\n', numTestSamples );

% Názvy features
PredictorNames = {'AoA_R1', 'AoA_R2', 'AoA_R3', 'AoA_R4', ...
                 'Res_R1_mm', 'Res_R2_mm', 'Res_R3_mm', 'Res_R4_mm', ...
                 'Amp_R1', 'Amp_R2', 'Amp_R3', 'Amp_R4'};

X_test_new = csvData{:, PredictorNames};

%% Příprava pro lokalizaci
numReaders = 4;

clear readers;
readers(numReaders) = struct('X',[],'Y',[],'AoA_azimuth_deg',[]);

% Čtečka 1 [m]
readers(1).X = 0.8195;       
readers(1).Y = -1.06535;

% Čtečka 2 [m]
readers(2).X = -0.24585;     
readers(2).Y = -0.8195;

% Čtečka 3 [m]
readers(3).X = -0.40975;     
readers(3).Y = 0.8195;

% Čtečka 4 [m]
readers(4).X = 0.6556;       
readers(4).Y = 1.06535;

% Výstupní tabulka
colNames = {'NazevSouboru', 'True_X_mm', 'True_Y_mm', ...
    'Err_Standard_mm', 'Err_Hard_mm', 'Err_Weighted_mm', ...
    'Weight_R1', 'Weight_R2', 'Weight_R3', 'Weight_R4', 'Outlier_Hard_Idx'};
varTypes = [{'string'}, repmat({'double'}, 1, 10)];

resultsTable = table('Size', [numTestSamples, length(colNames)], ...
    'VariableTypes', varTypes, 'VariableNames', colNames);

options = optimset('Display','off');

%% Hlavní smyčka přes dataset
for k = 1:numTestSamples
    
    row = csvData(k, :);

    true_X_m = row.True_X_mm / 1000;
    true_Y_m = row.True_Y_mm / 1000;

    err_standard_mm = sqrt((true_X_m - row.Est_X_m)^2 + (true_Y_m - row.Est_Y_m)^2) * 1000;

    readers(1).AoA_azimuth_deg = row.AoA_R1;
    readers(2).AoA_azimuth_deg = row.AoA_R2;
    readers(3).AoA_azimuth_deg = row.AoA_R3;
    readers(4).AoA_azimuth_deg = row.AoA_R4;

    % Predikce z RF pro aktuální nový řádek
    inputRF = X_test_new(k, :); 
    [~, scores] = predict(RFmodel, inputRF);
    rf_weights = 1 - scores(1, :); 

    % Tvrdé vyřazení
    [~, outlier_idx] = min(rf_weights);
    valid_readers = readers(setdiff(1:numReaders, outlier_idx));

    % Nový výchozí bod
    initial_guess = [row.Est_Y_m, row.Est_X_m];

    % Hard fminsearch
    func_hard = @(point) calculate_distance_to_lines_weight(point, valid_readers);
    pos_hard = fminsearch(func_hard, initial_guess, options);
    err_hard_mm = sqrt((true_X_m - pos_hard(2))^2 + (true_Y_m - pos_hard(1))^2) * 1000;

    % Vážený fminsearch (Soft)
    func_weighted = @(point) calculate_distance_to_lines_weight(point, readers, rf_weights);
    pos_weighted = fminsearch(func_weighted, initial_guess, options);
    err_weighted_mm = sqrt((true_X_m - pos_weighted(2))^2 + (true_Y_m - pos_weighted(1))^2) * 1000;

    % Zápis do tabulky
    resultsTable(k, :) = {row.NazevSouboru, row.True_X_mm, row.True_Y_mm, ...
        err_standard_mm, err_hard_mm, err_weighted_mm, ...
        rf_weights(1), rf_weights(2), rf_weights(3), rf_weights(4), outlier_idx};
end

%% Statistika
med_std  = median(resultsTable.Err_Standard_mm);
med_hard = median(resultsTable.Err_Hard_mm);
med_soft = median(resultsTable.Err_Weighted_mm);

avg_std  = mean(resultsTable.Err_Standard_mm);
avg_hard = mean(resultsTable.Err_Hard_mm);
avg_soft = mean(resultsTable.Err_Weighted_mm);

fprintf('\n Statistika (%s) \n', csvFile);
fprintf('   Standardní fminsearch:    Průměr: %6.2f mm | Medián: %6.2f mm \n', avg_std, med_std);
fprintf('   Tvrdé vyřazení (Hard):    Průměr: %6.2f mm | Medián: %6.2f mm \n', avg_hard, med_hard);
fprintf('   Vážený fminsearch (Soft): Průměr: %6.2f mm | Medián: %6.2f mm \n', avg_soft, med_soft);

%% Vizualizace
figure('Name', 'Cross-Evaluation RF', 'Color', 'w');

% Standard
subplot(1, 3, 1);
boxplot(resultsTable.Err_Standard_mm, 'Labels', {'Standardní'}, 'Symbol', 'b+', 'OutlierSize', 20);
set(gca, 'FontSize', 30);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2.5);
ylabel('Lokalizační chyba [mm]'); 
title('Bez RF'); 
grid on; 

% Hard
subplot(1, 3, 2);
boxplot(resultsTable.Err_Hard_mm, 'Labels', {'Hard RF'}, 'Symbol', 'b+', 'OutlierSize', 20);
set(gca, 'FontSize', 30);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2.5);
ylabel('Lokalizační chyba [mm]'); 
title('Tvrdé vyřazení'); 
grid on; 

% Soft
subplot(1, 3, 3);
boxplot(resultsTable.Err_Weighted_mm, 'Labels', {'Soft RF'}, 'Symbol', 'b+', 'OutlierSize', 20);
set(gca, 'FontSize', 30);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2.5);
ylabel('Lokalizační chyba [mm]'); 
title('Vážený fminsearch'); 
grid on; 