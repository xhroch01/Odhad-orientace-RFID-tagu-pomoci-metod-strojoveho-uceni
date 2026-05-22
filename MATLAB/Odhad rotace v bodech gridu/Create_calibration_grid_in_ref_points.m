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
