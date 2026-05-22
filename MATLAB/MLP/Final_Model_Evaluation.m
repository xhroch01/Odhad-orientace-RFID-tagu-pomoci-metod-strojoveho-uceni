%% Trénink, validace a testování jedné konkrétní MLP architektury
clear; 
clc; 
close all;

%% Načtení dat a Anti-Leakage Split
load('Augmented_Dataset_Amp_PhaseDiff_Lambda3.mat');
num_orig = 1304; 

% Fixace seedu rozdělení/míchání
rng(42, 'twister'); 
idx_base = randperm(num_orig); 

numTrain_base = floor(0.70 * num_orig);
numVal_base   = floor(0.15 * num_orig);

idxTrain_base = idx_base(1:numTrain_base);
idxVal_base   = idx_base(numTrain_base+1 : numTrain_base+numVal_base);
idxTest_base  = idx_base(numTrain_base+numVal_base+1 : end);

% Anonymní funkce - k základnímu indexu najde všechny jeho augmentované klony ležící vždy o +1304, +2608, +3912, +5216 a +6520 řádků níž
expand_idx = @(base) [base, base+num_orig, base+2*num_orig, base+3*num_orig, base+4*num_orig, base+5*num_orig];

idxTrain = expand_idx(idxTrain_base);
idxVal   = expand_idx(idxVal_base);
idxTest  = expand_idx(idxTest_base);

XTrain = X_Train_Augmented(idxTrain, :); 
YTrain = Y_Train_Augmented(idxTrain, :);

XVal   = X_Train_Augmented(idxVal, :);   
YVal   = Y_Train_Augmented(idxVal, :);

XTest  = X_Train_Augmented(idxTest, :);  
YTest  = Y_Train_Augmented(idxTest, :);

%% Normalizace
mu = mean(XTrain, 1);
sig = std(XTrain, 0, 1);
sig(sig == 0) = 1;

XTrain = (XTrain - mu) ./ sig;
XVal   = (XVal - mu) ./ sig;
XTest  = (XTest - mu) ./ sig;

numFeatures = size(XTrain, 2);

%% Definice Architektury
layers = [
    featureInputLayer(numFeatures, 'Normalization', 'none', 'Name', 'input')

    fullyConnectedLayer(256, 'Name', 'fc1')
    leakyReluLayer('Name', 'leakyrelu1')
    
    fullyConnectedLayer(203, 'Name', 'fc2')
    leakyReluLayer('Name', 'leakyrelu2')

    fullyConnectedLayer(4, 'Name', 'output')
    regressionLayer('Name', 'regressionoutput')];

%% Trénink Modelu

options = trainingOptions('adam', ...
    'MaxEpochs', 500, ...
    'MiniBatchSize',19, ...
    'InitialLearnRate', 0.00019, ...
    'L2Regularization', 0.00291, ...
    'ValidationData', {XVal, YVal}, ...
    'ValidationPatience', 30, ...
    'ValidationFrequency', 50, ...
    'Shuffle', 'every-epoch', ...
    'Plots', 'training-progress', ... 
    'Verbose', false);

fprintf('Trénink MLP modelu \n');
net = trainNetwork(XTrain, YTrain, layers, options);

save('MLP_Model.mat', 'net', 'mu', 'sig');

%% Evaluace výsledků
YPred = predict(net, XTest);

% Výpočet chyb
Err_Pos_m = sqrt((YTest(:,1) - YPred(:,1)).^2 + (YTest(:,2) - YPred(:,2)).^2);
Err_Pos_mm = Err_Pos_m * 1000;

Angle_True = atan2(YTest(:,4), YTest(:,3));
Angle_Pred = atan2(YPred(:,4), YPred(:,3));
Err_Rot_deg = rad2deg(abs(wrapToPi(Angle_True - Angle_Pred)));

% statistika na testovací sadě
fprintf('Počet pozic v testovací sadě: %d\n', length(Err_Pos_mm));
fprintf('Poloha - Medián: %.2f mm\n', median(Err_Pos_mm));
fprintf('Poloha - Průměr: %.2f mm\n', mean(Err_Pos_mm));

fprintf('\nRotace - Medián: %.2f stupňů\n', median(Err_Rot_deg));
fprintf('Rotace - Průměr: %.2f stupňů\n', mean(Err_Rot_deg));
fprintf('Rotace - P90 (90%% vzorků je lepších než): %.2f° \n', prctile(Err_Rot_deg, 90));

fprintf('\nPoloha - Min:    %.2f mm\n', min(Err_Pos_mm));
fprintf('Poloha - Max:    %.2f mm\n', max(Err_Pos_mm));
fprintf('Poloha - P90 (90%% vzorků je lepších než): %.2f mm\n', prctile(Err_Pos_mm, 90));

%% Vizualizace výsledků

% Boxplot
figure('Name', 'Boxploty Chyb', 'Color', 'w');

subplot(1, 2, 1); %rozdělení chyby polohy
boxplot(Err_Pos_mm, 'Labels', {'Chyba Polohy'}, 'Symbol', 'b+', 'OutlierSize', 15);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2);
set(gca, 'FontSize', 25);
ylabel('Chyba [mm]', 'FontSize', 25);
title('Rozdělení chyby polohy', 'FontSize', 25);
grid on;

subplot(1, 2, 2); %rozdělení chyby rotace
boxplot(Err_Rot_deg, 'Labels', {'Chyba Rotace'}, 'Symbol', 'b+', 'OutlierSize', 15);
h = findobj(gca, 'Type', 'Line');
set(h, 'LineWidth', 2);
set(gca, 'FontSize', 25);
ylabel('Chyba [°]', 'FontSize', 25);
title('Rozdělení chyby rotace', 'FontSize', 25);
grid on;

% Prostorove rozlozeni chyby
figure('Name', 'Rozložení chyb polohy', 'Color', 'w');
ax = gca;
ax.XAxis.FontSize = 20;
ax.YAxis.FontSize = 20;
hold on;

scatter(YTest(:,2), YTest(:,1), 65, Err_Pos_mm, 'filled'); % YTest(:,2) je Y, YTest(:,1) je X
cb = colorbar;
ylabel(cb, 'Chyba polohy [mm]', 'FontSize', 20);
colormap(jet);
xlabel('Osa Y [m]', 'FontSize', 20);
ylabel('Osa X [m]', 'FontSize', 20);
title('Rozložení chyb polohy na testovacích datech', 'FontSize', 25);
axis equal; 
grid on;
set(gca, 'YDir', 'reverse'); % Otočení osy X

% Vykreslení ctecek
readers_coords = [
    0.82, -1.07;  % Čtečka 1
   -0.25, -0.82;  % Čtečka 2
   -0.41,  0.82;  % Čtečka 3
    0.66,  1.07   % Čtečka 4
];

for i = 1:size(readers_coords, 1)

    rX = readers_coords(i, 1);
    rY = readers_coords(i, 2);

    % Čtečka
    plot(rY, rX, 'bs', 'MarkerSize', 20, 'MarkerFaceColor', 'blue');

    % Popisek čtečky
    text(rY + 0.05, rX, sprintf('Čtečka %d', i), 'Color', 'blue', 'FontSize', 23, 'FontWeight', 'bold');
end

hold off;

% Výpočet chyb rotace pro každý bod
Angle_True = atan2(YTest(:,4), YTest(:,3));
Angle_Pred = atan2(YPred(:,4), YPred(:,3));
err_deg_array = rad2deg(abs(wrapToPi(Angle_True - Angle_Pred)));

% Mapa chyb rotací
figure('Name', 'Rozložení chyb rotace', 'Color', 'w');
ax = gca;
ax.XAxis.FontSize = 20;
ax.YAxis.FontSize = 20;
hold on;

scatter(YTest(:,2), YTest(:,1), 65, err_deg_array, 'filled'); 
colormap('jet');
ylabel(colorbar, 'Chyba rotace [°]', 'FontSize', 20);
clim([0, 180]); % Strop barevné škály

grid on;
axis equal;
set(gca, 'YDir', 'reverse'); % Otočení osy X
xlabel('Osa Y [m]', 'FontSize', 20);
ylabel('Osa X [m]', 'FontSize', 20);
title('Rozložení chyb rotace na testovacích datech', 'FontSize', 25);

% Vykreslení ctecek
for i = 1:size(readers_coords, 1)
    rX = readers_coords(i, 1);
    rY = readers_coords(i, 2);
    plot(rY, rX, 'bs', 'MarkerSize', 15, 'MarkerFaceColor', 'blue');
    text(rY + 0.05, rX, sprintf('Čtečka %d', i), 'Color', 'blue', 'FontSize', 20, 'FontWeight', 'bold');
end

hold off;

%% Vyhodnocení šumu - oddělené testování

% Názvy jednotlivých vrstev
layer_names = {
    'Originální data', ...
    'Šum: SNR = 25 dB, Fáze std = 1.5°', ...
    'Šum: SNR = 20 dB, Fáze std = 3.0°', ...
    'Šum: SNR = 20 dB, Fáze std = 3.0°', ...
    'Šum: SNR = 18 dB, Fáze std = 4.0°', ...
    'Šum: SNR = 15 dB, Fáze std = 5.0°'
};

% Počet vzorků v jedné vrstvě testovací sady
num_test_base = length(idxTest_base); 

for i = 1:6
    % Výpočet začátku a konce pro aktuální vrstvu
    idx_start = (i-1) * num_test_base + 1;
    idx_end   = i * num_test_base;
    
    % Filtrace predikcí a skutečných hodnot jen pro konkrétní úroveň šumu
    YTest_layer = YTest(idx_start:idx_end, :);
    YPred_layer = YPred(idx_start:idx_end, :);
    
    % Výpočet chyb pro konkrétní vrstvu šumu
    Err_Pos_layer = sqrt((YTest_layer(:,1) - YPred_layer(:,1)).^2 + (YTest_layer(:,2) - YPred_layer(:,2)).^2) * 1000;
    
    Angle_True_l = atan2(YTest_layer(:,4), YTest_layer(:,3));
    Angle_Pred_l = atan2(YPred_layer(:,4), YPred_layer(:,3));
    Err_Rot_layer = rad2deg(abs(wrapToPi(Angle_True_l - Angle_Pred_l)));
    
    % Výpis výsledků na testovací sadě
    fprintf('[%d] %s\n', i, layer_names{i});
    fprintf('    Chyba polohy - Medián: %6.2f mm  | Průměr: %6.2f mm  | P90: %6.2f mm\n', median(Err_Pos_layer), mean(Err_Pos_layer), prctile(Err_Pos_layer, 90));
    fprintf('    Chyba rotace - Medián: %6.2f°    | Průměr: %6.2f°\n\n', median(Err_Rot_layer), mean(Err_Rot_layer));
end
