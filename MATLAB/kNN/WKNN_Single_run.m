%% SINGLE RUN: AoA + K-NN - bere v potaz 4 nejbližší body/cell podle nastavení ve vyhodnocení

clear; 
clc; 
close all;

%% Nastavení cest a načtení testovaných dat
dataFolder = 'sem vložit cestu ke složce s testovanými soubory'; %cesta k testovaným souborům

fileName = 'sem vložit název testovaného souboru'

fullPath = fullfile(dataFolder, fileName);

load('RFID_Square_Database_WKNN_lambda3.mat', 'Database'); % Načtení referenční mřížky - nastavit cestu pokud není soubor ve složce

load('RF_Model.mat', 'RFmodel'); % RF model

% NUTNO NASTAVIT LAMBDA V WKNN_rotation_estimate.m PODLE POUŽITÉHO GRIDU A ZPRACOVÁVANÝCH DAT

mode = 'wknn'; % NASTAVIT PODLE ZPRACOVÁVANÉ VARIANTY = 'cell' nebo 'wknn'

K = 4; % Nastavení k pro WkNN variantu

%% Vyhodnocení

% konkrétní buňka
[est_rot, true_rot, err_deg, info] = WKNN_rotation_estimate(fullPath, Database, RFmodel, K, mode);

fprintf('K-NN uzly: '); 
fprintf('[%.0f,%.0f] ', [info.node_X(info.knn_idx), info.node_Y(info.knn_idx)]'); 
fprintf('\n');
fprintf('Úhly v uzlech: '); 
fprintf('%.1f° ', info.est_ang_per_node); fprintf('\n');
fprintf('Váhy: '); 
fprintf('%.2f ', info.w); 
fprintf('\n');
fprintf('Odhad: %.1f° | Skutečnost: %.1f° | Chyba: %.1f° \n', ...
        est_rot, true_rot, abs(err_deg));

%% Vizualizace
figure('Name', 'Odhad orientace vazenym kNN', 'Color', 'w');
hold on; 
grid on; 
axis equal; 
set(gca, 'YDir', 'reverse');
ax = gca;
ax.XAxis.FontSize = 20;
ax.YAxis.FontSize = 20;

% Referenční mřížka
plot([Database.Y]/1000, [Database.X]/1000, '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 25);

% Oblast K-NN
knn_Y = info.node_Y(info.knn_idx)/1000; % souřadnice K uzlů [m]
knn_X = info.node_X(info.knn_idx)/1000;

% Alespoň 3 body pro definici plochy
if K >= 3
    try
        ch = convhull(knn_Y, knn_X);
        fill(knn_Y(ch), knn_X(ch), [1 0.92 0.92], 'EdgeColor', [0.7 0.3 0.3], ...
             'LineStyle', '--', 'FaceAlpha', 0.5);
    catch
        % Ignorovat chybu vykreslení, pokud jsou referenční body v přímce a netvoří 2D polygon
    end
end


% K-NN uzly
for n = 1:K

    nY = info.node_Y(info.knn_idx(n))/1000;
    nX = info.node_X(info.knn_idx(n))/1000;

    plot(nY, nX, 'o', 'Color', [0.75 0 0], 'MarkerSize', 15 + info.w(n)*50, 'LineWidth', 3); %zobrazení váhovaného uzlu, info.w(n) je výpočet velikosti kruhu podle váhy

    angle_rad = deg2rad(info.est_ang_per_node(n));

    plot([nY, nY + 0.10*cos(angle_rad)], [nX, nX + 0.10*sin(angle_rad)], 'm-', 'LineWidth', 3);

    text(nY + 0.05, nX + 0.05, sprintf('%.0f°\\newline w=%.2f', info.est_ang_per_node(n), info.w(n)), ...
         'Color', [0.5 0 0], 'FontSize', 23, 'FontWeight', 'bold');
end

% Čtečky a AoA paprsky
for i = 1:numel(info.readers)

    plot(info.readers(i).Y(1), info.readers(i).X(1), 'bs', 'MarkerSize', 20, 'MarkerFaceColor', 'b');

    text(info.readers(i).Y(1) + 0.04, info.readers(i).X(1) + 0.04, sprintf('Čtečka %d', i), ...
         'Color', 'b', 'FontSize', 20, 'FontWeight', 'bold');

    az = deg2rad(info.readers(i).AoA_azimuth_deg);

    plot([info.readers(i).Y(1), info.readers(i).Y(1) + 5*cos(az)], ...
         [info.readers(i).X(1), info.readers(i).X(1) + 5*sin(az)], 'g-', 'LineWidth', 2);
end

% Skutečná poloha + natočení
plot(info.true_Y/1000, info.true_X/1000, 'rx', 'MarkerSize', 20, 'LineWidth', 2.5);

true_az = deg2rad(true_rot);

plot([info.true_Y/1000, info.true_Y/1000 + 0.15*cos(true_az)], ...
     [info.true_X/1000, info.true_X/1000 + 0.15*sin(true_az)], 'r-', 'LineWidth', 1.5);

% Odhadnutá poloha + finální natočení
plot(info.pos_weighted(1), info.pos_weighted(2), 'ko', 'MarkerSize', 20, 'MarkerFaceColor', 'k');

estimated_az = deg2rad(est_rot);

plot([info.pos_weighted(1), info.pos_weighted(1) + 0.22*cos(estimated_az)], ...
     [info.pos_weighted(2), info.pos_weighted(2) + 0.22*sin(estimated_az)], 'b-', 'LineWidth', 3);

% Legenda
h = gobjects(1, 9);
h(1) = plot(NaN, NaN, 'bs', 'MarkerSize', 15, 'MarkerFaceColor', 'b'); % střed čtečky
h(2) = plot(NaN, NaN, 'g-', 'LineWidth', 1.2);
h(3) = plot(NaN, NaN, 'rx', 'MarkerSize', 10, 'LineWidth', 2);
h(4) = plot(NaN, NaN, 'r-', 'LineWidth', 1.5);
h(5) = plot(NaN, NaN, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
h(6) = plot(NaN, NaN, 'b-', 'LineWidth', 3);
h(7) = plot(NaN, NaN, '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 15);
h(8) = plot(NaN, NaN, 'o', 'Color', [0.75 0 0], 'MarkerSize', 10, 'LineWidth', 2);
h(9) = plot(NaN, NaN, 'm-', 'LineWidth', 1.5);
legend(h, {'Střed čtečky', 'Vypočítaný směr AoA', ...
           'Skutečná poloha', 'Skutečný směr natočení', ...
           'Odhadnutá poloha', 'Výsledný odhad natočení', ...
           'Referenční mřížka', 'K-NN uzly (velikost = váha)', ...
           'Lokální odhad úhlu v uzlu'}, ...
           'Location', 'best', 'FontSize', 20);

xlim([-1.5, 1.5]); 
ylim([-1, 1.25]);
xlabel('Osa Y [m]', 'FontSize', 20); 
ylabel('Osa X [m]', 'FontSize', 20);

[~, fName, ~] = fileparts(fileName);

title({strrep(fName, '_', '\_'), ...
       sprintf('Odhad: %.1f° | Skutečnost: %.1f° | Chyba: %.1f°', est_rot, true_rot, abs(err_deg))}, 'FontSize', 20);
hold off;