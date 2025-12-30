%% Příprava kalibrační tabulky - databáze
clear;
clc;
close all;

% Cesta ke složce s .fld soubory pro tvorbu kalibrační tabulky
data_folder = 'sem vložit cestu ke složce s kalibračními soubory';

% Získání seznamu všech .fld souborů
files = dir(fullfile(data_folder, '*.fld'));

% Inicializace prázdné struktury pro databázi - X, Y, RotXY, naměřený vektor (Fingerprint)
Database = struct('X', {}, 'Y', {}, 'RotXY', {}, 'Fingerprint_Cplx', {});

for i = 1:length(files)
    fileName = files(i).name;
    fullPath = fullfile(data_folder, fileName);

    % Určení pozice z názvu pro kal. tabulku
    txt_X = extractBetween(fileName, 'X_cs_', '_Y_cs_');
    txt_Y = extractBetween(fileName, 'Y_cs_', '_RotXY_');
    txt_RotXY = extractBetween(fileName, 'RotXY_', '_RotXZ_');

    txt_X = replace(txt_X, 'm', '-');
    txt_Y = replace(txt_Y, 'm', '-');
    txt_RotXY = replace(txt_RotXY, 'm', '-');

    val_X_mm = str2double(txt_X);
    val_Y_mm = str2double(txt_Y);
    val_RotXY = str2double(txt_RotXY);

    % Načtení dat z .fld
    data = readmatrix(fullPath, 'FileType', 'text', 'NumHeaderLines', 1);

    E_real = data(:, 4);
    E_imag = data(:, 5);

    % Komplexní vektor
    E_cplx = complex(E_real, E_imag);

    % Uložení dat do kalibrační tabulky
    Database(i).X = val_X_mm;
    Database(i).Y = val_Y_mm;
    Database(i).RotXY = val_RotXY;

    % Uložení komplexních dat pro interpolaci
    Database(i).Fingerprint_Cplx = E_cplx;
end

fprintf('\n Databáze obsahuje %d vzorků.\n', length(Database));

% Uložení databáze
save('RFID_Database.mat', 'Database');
disp('Kalibrační tabulka RFID_Database.mat');

%% Nastavení TESTOVANÝCH souborů
%  Odhad natočení pomocí interpolace Re a Im složek

load('RFID_Database.mat');

% Cesta ke složce se zpracovávanými .fld soubory
dataFolder = 'sem vložit cestu ke složce s testovanými soubory';

% Všechny .fld soubory ve složce
filePattern = fullfile(dataFolder, '*.fld');
theFiles = dir(filePattern);
fprintf('%d souborů k odhadu natočení.\n', length(theFiles));

Interpolation_methods = {'spline', 'linear', 'pchip', 'makima'};
numMethods = numel(Interpolation_methods);

% csv
colNames = {'NazevSouboru', ...
    'True_X_mm', 'True_Y_mm', ...
    'True_RotXY_deg', 'RotXY_estimated_deg', ...
    'Error_RotXY_deg', 'InterpMethod'};

varTypes = {'string', 'double', 'double', ...
    'double', 'double', ...
    'double', 'string'};

resultsTable = table('Size', [length(theFiles)*numMethods, length(colNames)], ...
    'VariableTypes', varTypes, ...
    'VariableNames', colNames);

rowIndex = 0;

%% Hlavní smyčka
for k = 1:length(theFiles)

    baseFileName = theFiles(k).name;
    fullFileName = fullfile(dataFolder, baseFileName);

    fprintf('Zpracovává se %d/%d: %s\n', k, length(theFiles), baseFileName);

    % Zjištění skutečné pozice testovaného souboru
    testFile = fullFileName;

    txt_true_X = extractBetween(testFile, 'X_cs_', '_Y_cs_');
    txt_true_Y = extractBetween(testFile, 'Y_cs_', '_RotXY_');
    txt_true_RotXY = extractBetween(testFile, 'RotXY_', '_RotXZ_');

    txt_true_X = replace(txt_true_X, 'm', '-');
    txt_true_Y = replace(txt_true_Y, 'm', '-');
    txt_true_RotXY = replace(txt_true_RotXY, 'm', '-');

    val_true_X_mm = str2double(txt_true_X);
    val_true_Y_mm = str2double(txt_true_Y);
    val_true_RotXY = str2double(txt_true_RotXY);

    % Načítání testovaných vzorků
    raw_data = readmatrix(testFile, 'FileType', 'text', 'NumHeaderLines', 1);

    % Načítání komplexního čísla
    E_meas_cplx = complex(raw_data(:, 4), raw_data(:, 5));

    % Příprava kalibrační tabulky (databáze)
    % Hledání shodné pozice mezi referencí a vzorkem
    index_match = find([Database.X] == val_true_X_mm & [Database.Y] == val_true_Y_mm);

    % Databáze shodných pozic X a Y mezi referencí a vzorkem
    subset = Database(index_match);
    [sorted_angles, sort_idx] = sort([subset.RotXY]);

    % Načtení dat pro interpolaci
    ref_matrix_cplx = [subset(sort_idx).Fingerprint_Cplx];

    % Smyčka přes interpolační metody
    fine_angles = -90:1:90;
    num_angles = length(fine_angles);

    for m = 1:numMethods

        % Pre-alokace pro proměnné
        interpolation_Re = zeros(20, num_angles);
        interpolation_Im = zeros(20, num_angles);

        Interpolation_method = Interpolation_methods{m};

        for i = 1:20

            vals_cplx = ref_matrix_cplx(i, :);

            % Interpolace Reálné části (1D data)
            interpolation_Re(i, :) = interp1(sorted_angles, real(vals_cplx), fine_angles, Interpolation_method);

            % Interpolace Imaginární části
            interpolation_Im(i, :) = interp1(sorted_angles, imag(vals_cplx), fine_angles, Interpolation_method);
        end

        % Složení zpět do komplexního čísla
        interpolation_Complex = complex(interpolation_Re, interpolation_Im);

        %% Výpočet chybové funkce (Komplexní Euklidovská vzdálenost)

        % Příprava chybové funkce
        error_function = zeros(1, num_angles);

        for ef = 1:num_angles

            % Dopočítání rozestupů mezi úhly
            Virtual_Fingerprint_cplx = interpolation_Complex(:, ef);

            % Vzdálenost v komplexní rovině: abs(z1 - z2)^2
            diff_vec = E_meas_cplx - Virtual_Fingerprint_cplx;

            % Výpočet chybové funkce pomocí metody nejmenších čtverců
            error_function(ef) = sum(abs(diff_vec).^2);

        end

        % Seznam nejmenších odchylek příslušných indexů
        [min_error, min_index] = min(error_function);

        % Určení odhadovaného úhlu z příslušného indexu
        estimated_angle = fine_angles(min_index);

        fprintf('\nOdhadnuté natočení (%s): %.1f°\n', Interpolation_method, estimated_angle);

        % Odchylka mezi realitou a měřením
        error_angle = estimated_angle - val_true_RotXY;
        fprintf('Odchylka natočení (%s): %.1f°\n', Interpolation_method, error_angle);
        fprintf('Skutečné natočení: %.1f°\n', val_true_RotXY);

        %% Uložení výsledku
        rowIndex = rowIndex + 1;
        resultsTable(rowIndex, :) = {baseFileName, ...
            val_true_X_mm, val_true_Y_mm, ...
            val_true_RotXY, estimated_angle, ...
            error_angle, Interpolation_method};

    end
end

%% Export

outputCsvFile = fullfile(dataFolder, 'Results_rotation_estimation.csv');
writetable(resultsTable, outputCsvFile);

fprintf('Tabulka uložena do: %s\n', outputCsvFile);

