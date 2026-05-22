clear; 
clc; 
close all;

%% Načtení dat a inicializace
load('Features_Lambda3.mat');

% Datasety k otestování
dataset_names = {'Dataset_ReIm', 'Dataset_AmpPhase', 'Dataset_ReImAmp', ...
                 'Dataset_ReImPhase', 'Dataset_ReImAmpPhase', ...
                 'Dataset_PhaseDiff', 'Dataset_Amp_PhaseDiff', ...
                 'Dataset_PhaseGrad', 'Dataset_Amp_Grad'};

num_datasets = length(dataset_names);
results = cell(num_datasets, 5);            % Jméno, Median_Poloha, Prumer_Poloha, Median_Rotace, Prumer_Rotace

for i = 1:num_datasets
    %% Výběr datasetu a fixace Seedu
    dataset_name = dataset_names{i};
    X_current = eval(dataset_name);
    
    % Zafixování generátoru náhodných čísel = vždy stejné rozdělení
    rng(42, 'twister'); 
    
    %% Rozdělení dat (70% Train, 15% Val, 15% Test)
    numSamples = size(X_current, 1);
    idx = randperm(numSamples);
    
    numTrain = floor(0.70 * numSamples);
    numVal   = floor(0.15 * numSamples);
    
    idxTrain = idx(1:numTrain);
    idxVal   = idx(numTrain+1 : numTrain+numVal);
    idxTest  = idx(numTrain+numVal+1 : end);
    
    XTrain = X_current(idxTrain, :); 
    YTrain = Y_all(idxTrain, :);

    XVal   = X_current(idxVal, :);   
    YVal   = Y_all(idxVal, :);

    XTest  = X_current(idxTest, :);  
    YTest  = Y_all(idxTest, :);
    
    %% Normalizace (podle trénovacích dat)
    mu = mean(XTrain, 1);
    sig = std(XTrain, 0, 1);
    sig(sig == 0) = 1;      % Ochrana proti dělení nulou
    
    XTrain = (XTrain - mu) ./ sig;
    XVal   = (XVal - mu) ./ sig;
    XTest  = (XTest - mu) ./ sig;
    
    %% Architektura - simple MLP
    numFeatures = size(XTrain, 2);
    
    layers = [
        featureInputLayer(numFeatures, 'Normalization', 'none', 'Name', 'input')

        fullyConnectedLayer(64, 'Name', 'fc1')
        reluLayer('Name', 'relu1')

        fullyConnectedLayer(32, 'Name', 'fc2')
        reluLayer('Name', 'relu2')

        fullyConnectedLayer(4, 'Name', 'output')

        regressionLayer('Name', 'regressionoutput')];
    
    %% Nastavení trénování
    options = trainingOptions('adam', ...
        'MaxEpochs', 150, ...
        'MiniBatchSize', 32, ...
        'ValidationData', {XVal, YVal}, ...
        'ValidationFrequency', 10, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', false, ...          
        'Plots', 'none');    

    
    %% Trénink sítě
    fprintf('Trénink MLP na datech: %s (Features: %d) \n', dataset_name, numFeatures);
    net = trainNetwork(XTrain, YTrain, layers, options);
    
    %% Evaluace na Testovacích datech
    YPred = predict(net, XTest);
    
    % Chyby polohy (X a Y = první a druhý sloupec v metrech)
    % Euklidovská vzdálenost mezi [X_true, Y_true] a [X_pred, Y_pred]
    Err_Pos_m = sqrt((YTest(:,1) - YPred(:,1)).^2 + (YTest(:,2) - YPred(:,2)).^2);
    Err_Pos_mm = Err_Pos_m * 1000; % Převod na milimetry
    
    % Chyby rotace (cos a sin = třetí a čtvrtý sloupec)
    % Zpětný převod ze sin a cos na úhel
    Angle_True = atan2(YTest(:,4), YTest(:,3));
    Angle_Pred = atan2(YPred(:,4), YPred(:,3));
    
    % Ošetření přechodu přes 360 stupňů
    Err_Rot_rad = abs(wrapToPi(Angle_True - Angle_Pred));
    Err_Rot_deg = rad2deg(Err_Rot_rad);
    
    %% Uložení výsledků do tabulky
    results{i, 1} = dataset_name;
    results{i, 2} = median(Err_Pos_mm);
    results{i, 3} = mean(Err_Pos_mm);
    results{i, 4} = median(Err_Rot_deg);
    results{i, 5} = mean(Err_Rot_deg);
end

%% Zobrazení srovnávací tabulky
fprintf('\n Výsledky na testovací sadě \n');
ResultsTable = cell2table(results, ...
    'VariableNames', {'Dataset', 'Median_Poloha_mm', 'Prumer_Poloha_mm', 'Median_Rotace_deg', 'Prumer_Rotace_deg'});

% Seřazení podle mediánu chyby polohy od nejlepšího
ResultsTable = sortrows(ResultsTable, 'Median_Poloha_mm');
disp(ResultsTable);