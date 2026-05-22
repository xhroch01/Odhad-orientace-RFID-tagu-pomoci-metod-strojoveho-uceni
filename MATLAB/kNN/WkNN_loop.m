%% zpracování LHS datasetu podle buňky, do kterého odhad patří nebo podle kNN

clear; 
clc; 
close all;

%% Načtení modelů a seznamu souborů
% načtení předzpracované referenční mřížky
load('RFID_square_Database_WKNN_lambda3.mat', 'Database'); % nastavit cestu pokud neni ve stejné složce

load('C:\Skola\Diplomka_RFID\ML\Priprava_odevzdani\RF_priprava_odevzdani\RF_Model.mat', 'RFmodel'); % načtení RF modelu - nutno nastavit cestu

dataFolder = 'C:\Sim\Dataset_tag_test\AoA_LHS_dataset\lambda3'; % Cesta ke zpracovávaným souborům

files = dir(fullfile(dataFolder, 'AoA_lambda3_*.fld'));
N = numel(files);

% NUTNO NASTAVIT LAMBDA V WKNN_rotation_estimate.m PODLE POUŽITÉHO GRIDU A ZPRACOVÁVANÝCH DAT

modes = {'wknn', 'cell'}; % obě metody

K = 4;

fprintf('Zpracování %d souborů, srovnání metod: %s \n', N, strjoin(modes, ', '));

%% Smyčka přes dataset - základní
errors_valid = nan(N, numel(modes));

for i = 1:N

    fn = fullfile(dataFolder, files(i).name);

    for m = 1:numel(modes)
        try
            [~, ~, e] = WKNN_rotation_estimate(fn, Database, RFmodel, K, modes{m});
            errors_valid(i, m) = abs(e);
        catch
            % Pozice mimo grid -> NaN
        end
    end

    if mod(i, 50) == 0
        fprintf(' %d/%d \n', i, N);
    end
end


%% Smyčka přes dataset - s vykreslením bodů které nezpracovaly
errors = nan(N, numel(modes));
failed_files = strings(0);  % seznam selhaných souborů
failed_pos = zeros(0, 2);   % jejich odhadnuté pozice

for i = 1:N

    fn = fullfile(dataFolder, files(i).name);

    for m = 1:numel(modes)
        try
            [~, ~, e, info] = WKNN_rotation_estimate(fn, Database, RFmodel, K, modes{m});

            errors(i, m) = abs(e);

        catch ME

            if strcmp(modes{m}, 'cell')
                [~, base, ~] = fileparts(files(i).name);

                tx = replace(extractBetween(base, 'X_cs_', '_Y_cs_'), 'm', '-');
                ty = replace(extractBetween(base, 'Y_cs_', '_RotXY_'), 'm', '-');

                failed_files(end+1) = string(files(i).name);
                failed_pos(end+1, :) = [str2double(tx), str2double(ty)];
            end
        end
    end
end



%% Statistika na souborech, kde obě metody vrátily výsledek

valid = ~any(isnan(errors_valid), 2);

fprintf(' Chyba natočení [°] (%d/%d) \n', sum(valid), N);
fprintf('%-8s %8s %8s %8s %8s \n', 'Mode', 'N', 'MAE', 'Med', 'P90');

for m = 1:numel(modes)

    e = errors_valid(valid, m);

    fprintf('%-8s %8d %8.2f %8.2f %8.2f \n', ...
        modes{m}, numel(e), mean(e), median(e), prctile(e, 90));
end

%% Zobrazení pozic selhaných v cell variantě
failed_idx = find(isnan(errors(:, 2)));  % indexy souborů, kde 'cell' selhal

failed_true_pos = zeros(numel(failed_idx), 2);  % skutečná pozice z názvu souboru
failed_est_pos  = zeros(numel(failed_idx), 2);  % odhadnutá pozice z lokalizace

for j = 1:numel(failed_idx)
    fn = fullfile(dataFolder, files(failed_idx(j)).name);

    % Skutečná pozice z názvu souboru
    [~, base, ~] = fileparts(files(failed_idx(j)).name);
    tx = replace(extractBetween(base, 'X_cs_', '_Y_cs_'), 'm', '-');
    ty = replace(extractBetween(base, 'Y_cs_', '_RotXY_'), 'm', '-');
    failed_true_pos(j, :) = [str2double(tx), str2double(ty)];

    % Odhadnutá pozice (přes 'wknn', která vždy projde)
    [~, ~, ~, info] = WKNN_rotation_estimate(fn, Database, RFmodel, 4, 'wknn');
    failed_est_pos(j, :) = [info.pos_weighted(2)*1000, info.pos_weighted(1)*1000];
    % pos_weighted(1) = Y, pos_weighted(2) = X
end

% Vizualizace
figure('Color', 'w'); 
hold on; 
grid on; 
axis equal; 
set(gca, 'YDir', 'reverse');
ax = gca;
ax.XAxis.FontSize = 20;
ax.YAxis.FontSize = 20;

% Grid
plot([Database.Y]/1000, [Database.X]/1000, '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 27);

% Skutečné pozice
plot(failed_true_pos(:,2)/1000, failed_true_pos(:,1)/1000, ...
     'rx', 'MarkerSize', 22, 'LineWidth', 3.5);

% Odhadnuté pozice
plot(failed_est_pos(:,2)/1000, failed_est_pos(:,1)/1000, ...
     'ko', 'MarkerSize', 16, 'LineWidth', 2, 'MarkerFaceColor', 'black');

% Spojnice mezi odhadem a skutečností
for j = 1:numel(failed_idx)
    plot([failed_true_pos(j,2), failed_est_pos(j,2)]/1000, ...
         [failed_true_pos(j,1), failed_est_pos(j,1)]/1000, ...
         'm--', 'LineWidth', 3);
end

xlabel('Osa Y [m]', 'FontSize', 23); 
ylabel('Osa X [m]', 'FontSize', 23);
title(sprintf('Selhané pozice v buňkové variantě (%d/%d)', numel(failed_idx), N), 'FontSize', 25);
legend({'Grid', 'Skutečná pozice', 'Odhadnutá pozice', 'Spojnice chyby'}, ...
       'Location', 'best', 'FontSize', 23);

