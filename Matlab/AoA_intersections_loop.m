% hledání pomocí metody průsečíků 

clear;
clc;
close all;

%% Nastavení vstupů

% Cesta ke složce se zpracovavanymi .fld soubory
dataFolder = 'sem vložit cestu ke složce s testovanými soubory'; % NUTNO SPRAVNE NASTAVIT ROZESTUPY SOND d_ref!!

% Najde všechny .fld soubory ve složce
filePattern = fullfile(dataFolder, '*.fld');
theFiles = dir(filePattern);

fprintf('%d souborů pro zpracování metodou průsečíků. \n', length(theFiles));

% Příprava csv
% Definice názvů sloupců pro CSV
colNames = {'NazevSouboru', ...
    'True_X_mm', 'True_Y_mm', ...
    'RotXY_deg', 'RotXZ_deg', 'RotYZ_deg', ...
    'Calc_X_mm', 'Calc_Y_mm', ...
    'Error_mm', ...
    'AoA_R1_deg', 'AoA_R2_deg', 'AoA_R3_deg', 'AoA_R4_deg'};

varTypes = {'string', 'double', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', 'double', 'double', 'double'};

resultsTable = table('Size', [length(theFiles), length(colNames)], ...
    'VariableTypes', varTypes, ...
    'VariableNames', colNames);

%% Main loop
for k = 1:length(theFiles)

    baseFileName = theFiles(k).name;
    fullFileName = fullfile(dataFolder, baseFileName);

    fprintf('Zpracovává se (%d/%d): %s\n', k, length(theFiles), baseFileName);

    % Reset proměnných
    clear readers a_coef b_coef c_coef;

    %% Získání skutečné polohy z názvu
    txt_X = extractBetween(baseFileName, 'X_cs_', '_Y_cs_');
    txt_Y = extractBetween(baseFileName, 'Y_cs_', '_RotXY_');
    txt_RotXY = extractBetween(baseFileName, 'RotXY_', '_RotXZ_');
    txt_RotXZ = extractBetween(baseFileName, 'RotXZ_', '_RotYZ_');
    txt_RotYZ = extractBetween(baseFileName, 'RotYZ_', '.fld');

    % Převod záporných čísel
    txt_X = replace(txt_X, 'm', '-');
    txt_Y = replace(txt_Y, 'm', '-');
    txt_RotXY = replace(txt_RotXY, 'm', '-');
    txt_RotXZ = replace(txt_RotXZ, 'm', '-');
    txt_RotYZ = replace(txt_RotYZ, 'm', '-');

    % Převod na čísla (txt -> val)
    val_X_mm = str2double(txt_X);
    val_Y_mm = str2double(txt_Y);
    val_RotXY = str2double(txt_RotXY);
    val_RotXZ = str2double(txt_RotXZ);
    val_RotYZ = str2double(txt_RotYZ);

    % Přepočet mm na m skrz graf
    true_X_m = val_X_mm / 1000;
    true_Y_m = val_Y_mm / 1000;

    %% Načítání dat a fáze

    data = readmatrix(fullFileName, 'FileType', 'text', 'NumHeaderLines', 1);

    f = 915e6;
    c = 3*10^8;
    lambda = c / f;
    d_ref = lambda / 4; % vzdálenost střed–okraj - !! upravovat podle .pts !!

    X_coord = data(:,1);
    Y_coord = data(:,2);
    Z_coord = data(:,3);
    E_real  = data(:,4);
    E_imag  = data(:,5);

    phase_rad = atan2(E_imag, E_real);

    %% Organizace dat do struktur
    numReaders = 4;
    numProbesPerReader = 5;
    readers(numReaders) = struct('X',[],'Y',[],'AoA_azimuth_deg',[]);

    for i = 1:numReaders
        startIndex = (i - 1) * numProbesPerReader + 1;
        endIndex = i * numProbesPerReader;
        index = startIndex:endIndex;

        readers(i).X = X_coord(index);
        readers(i).Y = Y_coord(index);
        readers(i).phase_rad = phase_rad(index);
    end

    %% AoA - výpočet

    wrapToPi = @(x) atan2(sin(x), cos(x));

    % Výpis jednotlivých úhlú čteček pro CSV
    current_AoAs = zeros(1, 4);

    for i = 1:numReaders
        phi_stred  = readers(i).phase_rad(1);
        phi_vlevo  = readers(i).phase_rad(2);
        phi_vpravo = readers(i).phase_rad(3);
        phi_nahore = readers(i).phase_rad(4);
        phi_dole   = readers(i).phase_rad(5);

        % Osa Y
        dphi_L = wrapToPi(phi_vlevo  - phi_stred);
        dphi_R = wrapToPi(phi_vpravo - phi_stred);
        u_y = (lambda / (2*pi*d_ref)) * 0.5 * (dphi_R - dphi_L);

        % Osa X
        dphi_T = wrapToPi(phi_nahore - phi_stred);
        dphi_B = wrapToPi(phi_dole   - phi_stred);
        u_x = (lambda / (2*pi*d_ref)) * 0.5 * (dphi_B - dphi_T);

        aoa_rad = atan2(u_x, u_y);

        readers(i).AoA_azimuth_deg = rad2deg(aoa_rad);

        current_AoAs(i) = readers(i).AoA_azimuth_deg;
    end

    %% Triangulace

    % Výpočet rovnic přímek (a*y + b*x = c)
    a_coef = zeros(1, numReaders);
    b_coef = zeros(1, numReaders);
    c_coef = zeros(1, numReaders);

    for i = 1:numReaders
        angle_rad = deg2rad(readers(i).AoA_azimuth_deg);
        val_a = -sin(angle_rad);
        val_b =  cos(angle_rad);
        val_c = val_a * readers(i).Y(1) + val_b * readers(i).X(1);

        a_coef(i) = val_a; b_coef(i) = val_b; c_coef(i) = val_c;
    end

    % Hledání nejlepší kombinace (trojúhelníku)
    combinations = nchoosek(1:numReaders, 3);
    min_error = inf;
    final_y = 0; final_x = 0;

    for m = 1:size(combinations, 1)
        idx_vec = combinations(m, :);
        pts_y = [];
        pts_x = [];

        % Nalezení 3 průsečíků uvnitř trojice
        pairs = nchoosek(idx_vec, 2);
        for p = 1:3
            [py, px] = solve_intersection(a_coef, b_coef, c_coef, pairs(p,1), pairs(p,2));
            pts_y = [pts_y, py];
            pts_x = [pts_x, px];
        end

        % Těžiště
        mean_y = mean(pts_y);
        mean_x = mean(pts_x);

        % Velikost trojúhelníku (chyba)
        total_tri_error = sum(sqrt((pts_y - mean_y).^2 + (pts_x - mean_x).^2));

        if total_tri_error < min_error
            min_error = total_tri_error;
            final_y = mean_y;
            final_x = mean_x;
        end
    end

    % Výsledek
    calc_Y_mm = final_y * 1000;
    calc_X_mm = final_x * 1000;

    %% Výpočet chyby (Pythagorova věta, Euklidovská vzdálenost)
    % Euklidovská vzdálenost mezi True a Calc
    dist_error_mm = sqrt((val_X_mm - calc_X_mm)^2 + (val_Y_mm - calc_Y_mm)^2);

    %% Uložení do tabulky
    resultsTable(k, :) = {baseFileName, ...
        val_X_mm, val_Y_mm, ...
        val_RotXY, val_RotXZ, val_RotYZ, ...
        calc_X_mm, calc_Y_mm, ...
        dist_error_mm, ...
        current_AoAs(1), current_AoAs(2), current_AoAs(3), current_AoAs(4)};
end

%% Konec + export
clc;

outputCsvFile = fullfile(dataFolder, 'Results_intersection_analysis.csv');
writetable(resultsTable, outputCsvFile);

fprintf('Tabulka uložena: %s\n', outputCsvFile);
disp('Náhled výsledků:');
disp(resultsTable(1:min(1, height(resultsTable)), :));


%% Funkce pro řešení soustavy rovnic
function [y, x] = solve_intersection(a, b, c, i1, i2)

% Soustava lineárních rovnic pro průsečík
Matrix = [a(i1), b(i1);
          a(i2), b(i2)];

Right = [c(i1);
         c(i2)];

result = Matrix \ Right;

y = result(1);
x = result(2);

end