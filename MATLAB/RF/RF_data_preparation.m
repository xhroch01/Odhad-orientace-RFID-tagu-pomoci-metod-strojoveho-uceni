clear;
clc;
close all;

%% Nastavení vstupů
dataFolder = 'C:\Sim\Dataset_tag_test\AoA_all_datasets\ALL_Lambda3'; % NASTAVIL LAMBDA PODLE DAT

filePattern = fullfile(dataFolder, '*.fld');

theFiles = dir(filePattern);

numFiles = length(theFiles);
 
% Cesta pro uložení výstupního CSV
outputFolder = 'C:\Sim\Dataset_tag_test\AoA_all_datasets';

fprintf('Zpracovává se %d souborů \n', numFiles);

%% testování nejlepšího tvaru dat pro RF

% Definice sloupců pro CSV
colNames = {'NazevSouboru', 'True_X_mm', 'True_Y_mm', ...
    'AoA_R1', 'AoA_R2', 'AoA_R3', 'AoA_R4', ...
    'Res_R1_mm', 'Res_R2_mm', 'Res_R3_mm', 'Res_R4_mm', ...
    'Est_Y_m', 'Est_X_m', ...
    'Amp_R1', 'Amp_R2', 'Amp_R3', 'Amp_R4', ...
    'dPhi_L1', 'dPhi_R1', 'dPhi_T1', 'dPhi_B1', ...
    'dPhi_L2', 'dPhi_R2', 'dPhi_T2', 'dPhi_B2', ...
    'dPhi_L3', 'dPhi_R3', 'dPhi_T3', 'dPhi_B3', ...
    'dPhi_L4', 'dPhi_R4', 'dPhi_T4', 'dPhi_B4', ...
    'Target_Outlier'};

% Prealokace proměnných
varTypes = repmat({'double'}, 1, length(colNames));
varTypes{1} = 'string';
varTypes{end} = 'categorical';

resultsTable = table('Size', [numFiles, length(colNames)], ...
    'VariableTypes', varTypes, 'VariableNames', colNames);

WrapToPi = @(x) atan2(sin(x), cos(x));

%% Hlavní smyčka
for k = 1:numFiles
    clear readers; % Reset struktury pro každý cyklus
    baseFileName = theFiles(k).name;
    fullFileName = fullfile(dataFolder, baseFileName);

    % Výpis zpracovnání
    if mod(k, 50) == 0
        fprintf('Zpracovává se (%d/%d) \n' , k, numFiles);
    end

    %% Získání skutečné polohy z názvu
    txt_X = extractBetween(baseFileName, 'X_cs_', '_Y_cs_');
    txt_Y = extractBetween(baseFileName, 'Y_cs_', '_RotXY_');

    val_X_mm = str2double(replace(txt_X, 'm', '-'));
    val_Y_mm = str2double(replace(txt_Y, 'm', '-'));

    true_X_m = val_X_mm / 1000;
    true_Y_m = val_Y_mm / 1000;

    %% Načítání dat ze souboru
    data = readmatrix(fullFileName, 'FileType', 'text', 'NumHeaderLines', 1);
    f = 915e6; 
    c = 3*10^8; 
    lambda = c/f; 
    d_ref = lambda/3;   % NASTAVIT LAMBDA PODLE DAT

    X_coord = data(:,1); 
    Y_coord = data(:,2);
    E_real = data(:,4); 
    E_imag = data(:,5);

    % Fáze v radiánech
    phase_rad = atan2(E_imag, E_real);

    numReaders = 4;
    readers(numReaders) = struct('X', [], 'Y', [], 'phase_rad', [], 'AoA_azimuth_deg', []);
    
    current_AoAs = zeros(1, 4);
    amp_centers = zeros(1, 4);
    phase_diffs = zeros(1, 16); % 4 čtečky * 4 rozdíly
    
    for i = 1:numReaders
        idx = ((i-1)*5 + 1) : (i*5);
        readers(i).X = X_coord(idx);
        readers(i).Y = Y_coord(idx);
        readers(i).phase_rad = phase_rad(idx);
        
        E_r = E_real(idx);
        E_i = E_imag(idx);
        
        % Amplituda středové sondy
        amp_centers(i) = sqrt(E_r(1)^2 + E_i(1)^2);
        
        % Fázové rozdíly mezi sondami
        phi_mid = readers(i).phase_rad(1);
        dphi_L = WrapToPi(readers(i).phase_rad(2) - phi_mid);
        dphi_R = WrapToPi(readers(i).phase_rad(3) - phi_mid);
        dphi_T = WrapToPi(readers(i).phase_rad(4) - phi_mid);
        dphi_B = WrapToPi(readers(i).phase_rad(5) - phi_mid);
        
        % Uložení fázových rozdílů pro zápis do CSV
        phase_idx = (i-1)*4 + 1;
        phase_diffs(phase_idx:phase_idx+3) = [dphi_L, dphi_R, dphi_T, dphi_B];
        
        % Výpočet AoA
        delta_phi_Y = 0.5 * (dphi_R - dphi_L);
        u_y = (lambda / (2*pi*d_ref)) * delta_phi_Y;
        
        delta_phi_X = 0.5 * (dphi_B - dphi_T);
        u_x = (lambda / (2*pi*d_ref)) * delta_phi_X;
        
        aoa_azimuth_rad = atan2(u_x, u_y);

        readers(i).AoA_azimuth_deg = rad2deg(aoa_azimuth_rad);
        current_AoAs(i) = readers(i).AoA_azimuth_deg;
    end

    %% Spuštění prvotního fminsearch k získání odhadnuté polohy a reziduí
    func_global = @(point) calculate_distance_to_lines_weight(point, readers);
    pos_global = fminsearch(func_global, [0, 0], optimset('Display','off'));

    est_Y = pos_global(1);
    est_X = pos_global(2);
    
    %% Výpočet reziduí k odhadnuté poloze
    % Geometrie implementována přímo (ne přes calculate_distance_to_lines_weight),
    % potrebujeme vzdálenost v mm, ne MNČ

    residuals_mm = zeros(1, 4);

    for i = 1:numReaders
        az_rad = deg2rad(readers(i).AoA_azimuth_deg);
        uY = cos(az_rad); 
        uX = sin(az_rad);

        A = -uX; 
        B = uY; 
        C = uX*readers(i).Y(1) - uY*readers(i).X(1);

        dist_m = abs(A*est_Y + B*est_X + C) / sqrt(A^2 + B^2);
        residuals_mm(i) = dist_m * 1000;
    end

    %% Hledání nejvychýlenější čtečky ze skutečné polohy
    true_dist_squared = zeros(1, 4);

    for i = 1:numReaders

        % Volání funkce s váhou=1 - vrací distance^2 pro jednu čtečku
        true_dist_squared(i) = calculate_distance_to_lines_weight([true_Y_m, true_X_m], readers(i));

    end

    [~, target_outlier] = max(true_dist_squared);
    
    %% Zápis všeho do jednoho řádku tabulky
    resultsTable(k, :) = {baseFileName, val_X_mm, val_Y_mm, ...
        current_AoAs(1), current_AoAs(2), current_AoAs(3), current_AoAs(4), ...
        residuals_mm(1), residuals_mm(2), residuals_mm(3), residuals_mm(4), ...
        est_Y, est_X, ...
        amp_centers(1), amp_centers(2), amp_centers(3), amp_centers(4), ...
        phase_diffs(1), phase_diffs(2), phase_diffs(3), phase_diffs(4), ...
        phase_diffs(5), phase_diffs(6), phase_diffs(7), phase_diffs(8), ...
        phase_diffs(9), phase_diffs(10), phase_diffs(11), phase_diffs(12), ...
        phase_diffs(13), phase_diffs(14), phase_diffs(15), phase_diffs(16), ...
        categorical(target_outlier)};
end

%% Uložení
% clc;
outputCsvFile = fullfile(outputFolder, 'Results_RF_data_lambda3.csv');
writetable(resultsTable, outputCsvFile);