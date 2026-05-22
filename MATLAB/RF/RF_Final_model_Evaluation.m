%% Trénink, evaluace a testování finálního RF modelu pro klasifikaci outlierů
clear; 
clc; 
close all;

%% Načtení a rozdělení dat
csvData = readtable('Results_RF_data_lambda3.csv');
num_orig = height(csvData);

% Názvy příznaků pro Random Forest
PredictorNames = {'AoA_R1', 'AoA_R2', 'AoA_R3', 'AoA_R4', ...
                 'Res_R1_mm', 'Res_R2_mm', 'Res_R3_mm', 'Res_R4_mm', ...
                 'Amp_R1', 'Amp_R2', 'Amp_R3', 'Amp_R4'};

X_all = csvData{:, PredictorNames};
Y_all = categorical(csvData.Target_Outlier); % definice pro klasifikaci

% Fixace seedu
rng(42, 'twister'); 
idx_base = randperm(num_orig); 

% Rozdělení dat: 85% Trénink + validace (OOB), 15% Test
numTrain = floor(0.85 * num_orig);

idxTrain = idx_base(1:numTrain); % 85%
idxTest  = idx_base(numTrain+1 : end); % 15%

XTrain = X_all(idxTrain, :); 
YTrain = Y_all(idxTrain, :);
XTest  = X_all(idxTest, :);  
YTest  = Y_all(idxTest, :);

numTestSamples = length(idxTest);
fprintf('Načteno %d datových souborů - Trénink: %d, Testování: %d \n', num_orig, numTrain, numTestSamples);

%% Definice Architektury
trees = 267; 
leaf = 10; 
mtry = 6;
splits = 75;

fprintf('\n Trénování RF modelu (Trees: %d, Leaf: %d, mtry: %d, Splits: %d) \n', trees, leaf, mtry, splits);

% Definice architektury
t = templateTree('MinLeafSize', leaf, ...
                 'NumVariablesToSample', mtry, ...
                 'MaxNumSplits', splits);

%% Trénink Modelu
RFmodel = fitcensemble(XTrain, YTrain, 'Method', 'Bag', 'NumLearningCycles', trees, ...
     'Learners', t, 'PredictorNames', PredictorNames);

save('RF_Model.mat', 'RFmodel');

%% Evaluace klasifikace
% Získání kumulativních chyb v závislosti na počtu stromů
err_train_cum = loss(RFmodel, XTrain, YTrain, 'Mode', 'cumulative');
err_oob_cum   = oobLoss(RFmodel, 'Mode', 'cumulative'); % OOB nahrazuje validaci
err_test_cum  = loss(RFmodel, XTest, YTest, 'Mode', 'cumulative');

% Predikce pro testovací data
YPred_Test = predict(RFmodel, XTest); 

fprintf('Přesnost klasifikace outlierů na testovací sadě: %.2f %%\n\n', (1 - err_test_cum(end)) * 100);

%% Vizualizace klasifikace
figure('Name', 'Analýza RF Modelu', 'Color', 'w');

% Křivka učení
subplot(1, 2, 1);
plot(1:trees, err_train_cum, 'b-', 'LineWidth', 2); 
hold on;
plot(1:trees, err_oob_cum, 'r-', 'LineWidth', 2);
plot(1:trees, err_test_cum, 'g-', 'LineWidth', 2);
grid on;
xlabel('Počet stromů v lese', 'FontSize', 25); 
ylabel('Klasifikační chybovost', 'FontSize', 25);
title('Průběh učení', 'FontSize', 25);
legend('Trénink', 'OOB - Validace', 'Test', 'Location', 'best', 'FontSize', 25);
set(gca, 'FontSize', 25);

% Matice záměn (Testovací data)
subplot(1, 2, 2);
cm = confusionchart(YTest, YPred_Test);
cm.Title = 'Matice záměn (Testovací data)';
cm.FontSize = 30;
cm.RowSummary = 'row-normalized';
cm.ColumnSummary = 'column-normalized';

%% Příprava pro evaluaci lokalizace (fminsearch)
numReaders = 4;

clear readers;
readers(numReaders) = struct('X',[],'Y',[],'AoA_azimuth_deg',[]);

% Reader 1 [m]
readers(1).X = 0.8195;       
readers(1).Y = -1.06535;

% Reader 2 [m]
readers(2).X = -0.24585;     
readers(2).Y = -0.8195;

% Reader 3 [m]
readers(3).X = -0.40975;     
readers(3).Y = 0.8195;

% Reader 4 [m]
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

%% Smyčka přes testovací data
for k = 1:numTestSamples
    
    % Získání skutečného řádku testovaného vzorku z původního CSV
    actual_row_idx = idxTest(k);
    row = csvData(actual_row_idx, :);

    true_X_m = row.True_X_mm / 1000;
    true_Y_m = row.True_Y_mm / 1000;

    err_standard_mm = sqrt((true_X_m - row.Est_X_m)^2 + (true_Y_m - row.Est_Y_m)^2) * 1000;

    readers(1).AoA_azimuth_deg = row.AoA_R1;
    readers(2).AoA_azimuth_deg = row.AoA_R2;
    readers(3).AoA_azimuth_deg = row.AoA_R3;
    readers(4).AoA_azimuth_deg = row.AoA_R4;

    % Připravená testovací data XTest
    inputRF = XTest(k, :); 

    % Predikce - získání pravděpodobnosti z funkce pretict
    [~, scores] = predict(RFmodel, inputRF);
    rf_weights = 1 - scores(1, :); 

    % Tvrdé vyřazení
    [~, outlier_idx] = min(rf_weights);
    valid_readers = readers(setdiff(1:numReaders, outlier_idx));

    initial_guess = [row.Est_Y_m, row.Est_X_m];

    func_hard = @(point) calculate_distance_to_lines_weight(point, valid_readers);
    pos_hard = fminsearch(func_hard, initial_guess, options);
    err_hard_mm = sqrt((true_X_m - pos_hard(2))^2 + (true_Y_m - pos_hard(1))^2) * 1000;

    % Vážený fminsearch
    func_weighted = @(point) calculate_distance_to_lines_weight(point, readers, rf_weights);
    pos_weighted = fminsearch(func_weighted, initial_guess, options);
    err_weighted_mm = sqrt((true_X_m - pos_weighted(2))^2 + (true_Y_m - pos_weighted(1))^2) * 1000;

    % Zápis do tabulky
    resultsTable(k, :) = {row.NazevSouboru, row.True_X_mm, row.True_Y_mm, ...
        err_standard_mm, err_hard_mm, err_weighted_mm, ...
        rf_weights(1), rf_weights(2), rf_weights(3), rf_weights(4), outlier_idx};
end

%% Statistika výsledků
med_std  = median(resultsTable.Err_Standard_mm);
med_hard = median(resultsTable.Err_Hard_mm);
med_soft = median(resultsTable.Err_Weighted_mm);

avg_std  = mean(resultsTable.Err_Standard_mm);
avg_hard = mean(resultsTable.Err_Hard_mm);
avg_soft = mean(resultsTable.Err_Weighted_mm);

fprintf('\n Statistika na testovacích datech \n');
fprintf('   Standardní fminsearch:    Průměr: %6.2f mm | Medián: %6.2f mm \n', avg_std, med_std);
fprintf('   Tvrdé vyřazení:           Průměr: %6.2f mm | Medián: %6.2f mm \n', avg_hard, med_hard);
fprintf('   Vážený fminsearch:        Průměr: %6.2f mm | Medián: %6.2f mm \n', avg_soft, med_soft);

%% Vizualizace lokalizačních chyb
figure('Name', 'Porovnání lokalizačních chyb RF', 'Color', 'w');

% 1. Standardní fminsearch
subplot(1, 3, 1);
boxplot(resultsTable.Err_Standard_mm, 'Labels', {'Standardní'}, 'Symbol', 'b+', 'OutlierSize', 15);
set(gca, 'FontSize', 25);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2.5);
ylabel('Lokalizační chyba [mm]');
title('Bez RF');
grid on;

% 2. Tvrdé vyřazení
subplot(1, 3, 2);
boxplot(resultsTable.Err_Hard_mm, 'Labels', {'Hard RF'}, 'Symbol', 'b+', 'OutlierSize', 15);
set(gca, 'FontSize', 25);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2.5);
ylabel('Lokalizační chyba [mm]');
title('Tvrdé vyřazení');
grid on;

% 3. Vážený fminsearch
subplot(1, 3, 3);
boxplot(resultsTable.Err_Weighted_mm, 'Labels', {'Soft RF'}, 'Symbol', 'b+', 'OutlierSize', 15);
set(gca, 'FontSize', 25);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2.5);
ylabel('Lokalizační chyba [mm]');
title('Vážený fminsearch');
grid on;