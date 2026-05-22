%% Nastavení TESTOVANÝCH souborů
% Odhad natočení pomocí interpolace Re a Im složek

clear;
clc;
close all;

load('RFID_Database.mat'); % Načtení referenční databáze

testFile = 'sem vložit cestu ke složce s testovaným souborem + název konkrétního souboru';

txt_true_X = extractBetween(testFile, 'X_cs_', '_Y_cs_');
txt_true_Y = extractBetween(testFile, 'Y_cs_', '_RotXY_');
txt_true_RotXY = extractBetween(testFile, 'RotXY_', '_RotXZ_');

txt_true_X = replace(txt_true_X, 'm', '-');
txt_true_Y = replace(txt_true_Y, 'm', '-');
txt_true_RotXY = replace(txt_true_RotXY, 'm', '-');

val_true_X_mm = str2double(txt_true_X);
val_true_Y_mm = str2double(txt_true_Y);
val_true_RotXY = str2double(txt_true_RotXY);

%% Načítání testovaných vzorků

raw_data = readmatrix(testFile, 'FileType', 'text', 'NumHeaderLines', 1);

% Načtení komplexní čísla
E_meas_cplx = complex(raw_data(:, 4), raw_data(:, 5));

%% Příprava kalibrační tabulky (databáze)
% Hledání shodné pozice mezi referencí a vzorkem
index_match = find([Database.X] == val_true_X_mm & [Database.Y] == val_true_Y_mm);

% Databáze shodných pozic X a Y mezi referencí a vzorkem
subset = Database(index_match);
[sorted_angles, sort_idx] = sort([subset.RotXY]);

% Načtení dat pro interpolaci
ref_matrix_cplx = [subset(sort_idx).Fingerprint_Cplx];

%% Interpolace (Re a Im zvlášť)
fine_angles = -90:1:90;
num_angles = length(fine_angles);

% Pre-alokace pro proměnné
interpolation_Re = zeros(20, num_angles);
interpolation_Im = zeros(20, num_angles);

Interpolation_method = 'spline'; % Nastavení konkrétní interpolace

for i = 1:20
    vals_cplx = ref_matrix_cplx(i, :);

    % Interpolace Re části
    interpolation_Re(i, :) = interp1(sorted_angles, real(vals_cplx), fine_angles, Interpolation_method);

    % Interpolace Im části
    interpolation_Im(i, :) = interp1(sorted_angles, imag(vals_cplx), fine_angles, Interpolation_method);
end

% Složení zpět do komplexního čísla
interpolation_Complex = complex(interpolation_Re, interpolation_Im);

%% Výpočet chybové funkce (Komplexní Euklidovská vzdálenost)

%Příprava chybové funkce
error_function = zeros(1, num_angles);

for k = 1:num_angles

    % Dopočítání rozestupů mezi úhly
    Virtual_Fingerprint_cplx = interpolation_Complex(:, k);

    % Vzdálenost v komplexní rovině: abs(z1 - z2)^2
    diff_vec = E_meas_cplx - Virtual_Fingerprint_cplx;

    % Výpočet chybové funkce pomocí metody nejmenších čtverců
    error_function(k) = sum(abs(diff_vec).^2);

end

% Seznam nejmenších odchylek a jejich příslušných indexů
[min_error, min_index] = min(error_function);

% Určení odhadovaného úhlu z příslušného indexu
estimated_angle = fine_angles(min_index);

fprintf('\n Odhadnuté natočení: %.1f°\n', estimated_angle);

% Odchylka mezi realitou a měřením
error_angle = estimated_angle - val_true_RotXY;
fprintf('Odchylka natočení: %.1f°\n', error_angle);
fprintf('Skutečné natočení: %.1f°\n', val_true_RotXY);

%% Vizualizace
figure('Name', 'Komplexní analýza', 'Color', 'w');

plot(fine_angles, error_function, 'b-', 'LineWidth', 2);
hold on;
plot(estimated_angle, min_error, 'ro','MarkerFaceColor', 'r', 'MarkerSize', 14, 'LineWidth', 2);

grid on;
title(sprintf('Chybová funkce (Minimum: %.1f°)', estimated_angle), 'FontSize', 30);
ylabel('Komplexní chyba [(V/m)^2]','FontSize', 30);
xlabel('Úhel [°]','FontSize', 30)
ax = gca;
ax.XAxis.FontSize = 25;
ax.YAxis.FontSize = 25;
