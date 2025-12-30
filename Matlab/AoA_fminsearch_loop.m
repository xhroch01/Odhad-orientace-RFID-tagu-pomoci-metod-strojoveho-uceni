% hledání pomocí metody fminsearch

clear;
clc;
close all;

%% Nastavení vstupů

% Cesta ke složce se zpracovavanymi .fld soubory
dataFolder = 'sem vložit cestu ke složce s testovanými soubory'; % NUTNO SPRAVNE NASTAVIT ROZESTUPY SOND d_ref!!


% Najde všechny .fld soubory ve složce
filePattern = fullfile(dataFolder, '*.fld');
theFiles = dir(filePattern);

fprintf('%d souborů pro zpracování metodou fminsearch. \n', length(theFiles));

% Definice názvů sloupců pro CSV
colNames = {'NazevSouboru', ...
    'True_X_mm', 'True_Y_mm', ...
    'RotXY_deg', 'RotXZ_deg', 'RotYZ_deg', ...
    'Calc_X_mm', 'Calc_Y_mm', ...
    'Error_mm', ...
    'AoA_R1_deg', 'AoA_R2_deg', 'AoA_R3_deg', 'AoA_R4_deg'};

% Definice proměnných (string - název, ostatní - double)
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
    clear readers;

    % Extrakce hodnot z názvu souboru
    txt_X = extractBetween(baseFileName, 'X_cs_', '_Y_cs_');
    txt_Y = extractBetween(baseFileName, 'Y_cs_', '_RotXY_');
    txt_RotXY = extractBetween(baseFileName, 'RotXY_', '_RotXZ_');
    txt_RotXZ = extractBetween(baseFileName, 'RotXZ_', '_RotYZ_');
    txt_RotYZ = extractBetween(baseFileName, 'RotYZ_', '.fld');

    % Ošetření záporných čísel ('m' -> '-')
    txt_X = replace(txt_X, 'm', '-');
    txt_Y = replace(txt_Y, 'm', '-');
    txt_RotXY = replace(txt_RotXY, 'm', '-');
    txt_RotXZ = replace(txt_RotXZ, 'm', '-');
    txt_RotYZ = replace(txt_RotYZ, 'm', '-');

    % Převod na čísla
    val_X_mm = str2double(txt_X);
    val_Y_mm = str2double(txt_Y);
    val_RotXY = str2double(txt_RotXY);
    val_RotXZ = str2double(txt_RotXZ);
    val_RotYZ = str2double(txt_RotYZ);

    % Přepočet na metry pro výpočet chyby
    true_X_m = val_X_mm / 1000;
    true_Y_m = val_Y_mm / 1000;

    %% Načítání dat a fáze

    data = readmatrix(fullFileName, 'FileType', 'text', 'NumHeaderLines', 1);

    f = 915e6;
    c = (3*10)^8;
    lambda = c / f;
    d_ref = lambda / 4; % vzdálenost střed–okraj - !! upravovat podle .pts !!

    X_coord = data(:,1);
    Y_coord = data(:,2);
    Z_coord = data(:,3);
    E_real  = data(:,4);
    E_imag  = data(:,5);

    % Výpočet fáze
    phase_rad = atan2(E_imag, E_real);

    %% Organizace dat do struktur
    numReaders = 4;
    numProbesPerReader = 5;
    readers(numReaders) = struct('X',[],'Y',[],'AoA_azimuth_deg',[]);
    probeNames = {'Střed (.1)', 'Vlevo (.2)', 'Vpravo (.3)', 'Nahoře (.4)', 'Dole (.5)'};

    for i = 1:numReaders
        startIndex = (i - 1) * numProbesPerReader + 1;
        endIndex = i * numProbesPerReader;
        index = startIndex:endIndex;

        readers(i).X = X_coord(index);
        readers(i).Y = Y_coord(index);
        readers(i).phase_rad = phase_rad(index);
        readers(i).probeNames = probeNames;
    end

    %% AoA - výpočet

    wrapToPi = @(x) atan2(sin(x), cos(x));

    % Pomocné pole pro uložení úhlů pro export
    current_AoAs = zeros(1, 4);

    for i = 1:numReaders
        phi_middle = readers(i).phase_rad(1);
        phi_left   = readers(i).phase_rad(2);
        phi_right = readers(i).phase_rad(3);
        phi_up = readers(i).phase_rad(4);
        phi_down   = readers(i).phase_rad(5);

        % Osa Y
        dphi_L = wrapToPi(phi_left  - phi_middle);
        dphi_R = wrapToPi(phi_right - phi_middle);
        u_y = (lambda / (2*pi*d_ref)) * 0.5 * (dphi_R - dphi_L);

        % Osa X
        dphi_T = wrapToPi(phi_up - phi_middle);
        dphi_B = wrapToPi(phi_down   - phi_middle);
        u_x = (lambda / (2*pi*d_ref)) * 0.5 * (dphi_B - dphi_T);

        aoa_rad = atan2(u_x, u_y);
        readers(i).AoA_azimuth_deg = rad2deg(aoa_rad);

        % Úhel pro CSV
        current_AoAs(i) = readers(i).AoA_azimuth_deg;
    end

    %% Triangulace (fminsearch)
    initial_guess = [0, 0];

    % funkce pro předání readers
    % readers - fixní data, point - hledaná data, která se mění a předávají dál
    % označená @(point)
    triangulation_function = @(point) calculate_distance_to_lines(point, readers);

    options = optimset('Display','off');
    calculated_position_YX = fminsearch(triangulation_function, initial_guess, options);

    calc_Y_mm = calculated_position_YX(1) * 1000;
    calc_X_mm = calculated_position_YX(2) * 1000;

    %% Výpočet chyby
    % Euklidovská vzdálenost mezi True a Calc
    dist_error_mm = sqrt((val_X_mm - calc_X_mm)^2 + (val_Y_mm - calc_Y_mm)^2);

    %% Uložení do tabulky
    % Naplnění tabulky daty
    resultsTable(k, :) = {baseFileName, ...
        val_X_mm, val_Y_mm, ...
        val_RotXY, val_RotXZ, val_RotYZ, ...
        calc_X_mm, calc_Y_mm, ...
        dist_error_mm, ...
        current_AoAs(1), current_AoAs(2), current_AoAs(3), current_AoAs(4)};

end

%% Konec + export
clc;

% Uložení tabulky do CSV
outputCsvFile = fullfile(dataFolder, 'Results_fminsearch_analysis.csv');
writetable(resultsTable, outputCsvFile);

fprintf('Tabulka byla uložena: %s\n', outputCsvFile);
disp('Prvních 5 řádků výsledné tabulky:');
disp(resultsTable(1:min(5, height(resultsTable)), :));