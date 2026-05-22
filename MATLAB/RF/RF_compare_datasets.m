% Porovnání 8 různých sad příznaků
clear; 
clc; 
close all;

%% Načtení dat
data = readtable('Results_RF_data_lambda3.csv');

Y_all = data.Target_Outlier;

% Rozdělení na Trénink (80%) a Test (20%)
rng(42, 'twister'); 
cv = cvpartition(size(data, 1), 'HoldOut', 0.20);

idxTrain = training(cv);
idxTest  = test(cv);

YTrain = Y_all(idxTrain);
YTest  = Y_all(idxTest);

%% Definice sad příznaků k testování
% Názvů sloupců
feat_AoA = {'AoA_R1', 'AoA_R2', 'AoA_R3', 'AoA_R4'};
feat_Res = {'Res_R1_mm', 'Res_R2_mm', 'Res_R3_mm', 'Res_R4_mm'};
feat_Est = {'Est_Y_m', 'Est_X_m'};
feat_Amp = {'Amp_R1', 'Amp_R2', 'Amp_R3', 'Amp_R4'};
feat_dPhi = {'dPhi_L1', 'dPhi_R1', 'dPhi_T1', 'dPhi_B1', ...
             'dPhi_L2', 'dPhi_R2', 'dPhi_T2', 'dPhi_B2', ...
             'dPhi_L3', 'dPhi_R3', 'dPhi_T3', 'dPhi_B3', ...
             'dPhi_L4', 'dPhi_R4', 'dPhi_T4', 'dPhi_B4'};

% AoA + Rezidua
Sets(1).Name = 'S1: AoA + Res';
Sets(1).Features = [feat_AoA, feat_Res];

% AoA + Rezidua + Est
Sets(2).Name = 'S2: AoA + Res + Est';
Sets(2).Features = [feat_AoA, feat_Res, feat_Est];

% AoA + Rezidua + Amplitudy
Sets(3).Name = 'S3: AoA + Res + Amp';
Sets(3).Features = [feat_AoA, feat_Res, feat_Amp];

% AoA + Rezidua + Est + Amplitudy
Sets(4).Name = 'S4: AoA + Res + Est + Amp';
Sets(4).Features = [feat_AoA, feat_Res, feat_Est, feat_Amp];

% Rezidua + Fázové rozdíly
Sets(5).Name = 'S5: Res + dPhi';
Sets(5).Features = [feat_Res, feat_dPhi];

% Rezidua + Amplitudy + Fázové rozdíly
Sets(6).Name = 'S6: Res + Amp + dPhi';
Sets(6).Features = [feat_Res, feat_Amp, feat_dPhi];

% AoA + Amp + dPhi
Sets(7).Name = 'S7: AoA, Amp, dPhi';
Sets(7).Features = [feat_AoA, feat_Amp, feat_dPhi];

% Všechny prediktory
Sets(8).Name = 'S8: Všechny';
Sets(8).Features = [feat_AoA, feat_Res, feat_Est, feat_Amp, feat_dPhi];

numSets = length(Sets);
accuracies = zeros(numSets, 1);

%% Trénink a evaluace základní RF pro každou sadu - pro test nejlepšího RF tento blok zakomentovat
trees = 50; 
leafs = 10; 

t = templateTree('MinLeafSize', leafs);

for i = 1:numSets
    fprintf('Testování sady: %s; příznaků: %d - ', Sets(i).Name, length(Sets(i).Features));

    XTrain = data{idxTrain, Sets(i).Features};
    XTest  = data{idxTest, Sets(i).Features};

    % RF = 50 stromů, MinLeafSize = 10
    net = fitcensemble(XTrain, YTrain, 'Method', 'Bag', 'NumLearningCycles', trees, ...
        'Learners', t, 'PredictorNames', Sets(i).Features);

    err_test = loss(net, XTest, YTest);
    acc_test = (1 - err_test) * 100;

    accuracies(i) = acc_test;
    fprintf('Přesnost: %.2f %%\n', acc_test);
end

%% Trénink a evaluace optimalizovaného RF pro každou sadu
% Nejlepší nalezené hyperparametry - odkomentovat pro test teto kombinace
% Zakomentovat blok výše Trénink a evaluace Baseline RF pro každou sadu
% trees = 267; 
% leafs = 10; 
% mtry = 6; 
% splits = 75;
% 
% for i = 1:numSets
%     fprintf('Testovaná sada %s (%d příznaků) ', Sets(i).Name, length(Sets(i).Features));
% 
%     XTrain = data{idxTrain, Sets(i).Features};
%     XTest  = data{idxTest, Sets(i).Features};
% 
%     % Zajištění, že mtry nepřekročí počet dostupných příznaků v dané sadě
%     current_mtry = min(mtry, length(Sets(i).Features));
% 
%     % Definice šablony stromu s optimalizovanými parametry
%     t = templateTree('MinLeafSize', leafs, ...
%                      'NumVariablesToSample', current_mtry, ...
%                      'MaxNumSplits', splits);
% 
%     % Trénink optimalizovaného lesa
%     net = fitcensemble(XTrain, YTrain, 'Method', 'Bag', 'NumLearningCycles', trees, ...
%         'Learners', t, 'PredictorNames', Sets(i).Features);
% 
%     % Evaluace přesnosti
%     err_test = loss(net, XTest, YTest);
%     acc_test = (1 - err_test) * 100;
% 
%     accuracies(i) = acc_test;
%     fprintf('Přesnost: %.2f %%\n', acc_test);
% end

% Vykreslení výsledků
figure('Name', 'Porovnání sad příznaků');

b = bar(accuracies, 'FaceColor', [0.2 0.6 0.8]);

% Přidání textových popisků
xticklabels({Sets.Name});
xtickangle(25); % Natočení kvůli delším názvům a 8 sloupcům

ylim([min(accuracies)-4, max(accuracies)+4]); 
ylabel('Klasifikační přesnost [%]', 'FontSize', 12, 'FontWeight', 'bold');
title('Vliv 8 testovaných sad příznaků na přesnost modelu', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

for i = 1:numSets
    text(i, accuracies(i) + 0.5, sprintf('%.1f %%', accuracies(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
end

[best_acc, best_idx] = max(accuracies);
fprintf('Nejlepší výsledek = %s, přesnost: %.2f %%.\n', Sets(best_idx).Name, best_acc);