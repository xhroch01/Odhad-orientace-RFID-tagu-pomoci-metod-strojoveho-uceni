% hledání pomocí funkce fminsearch
%% Načtení dat

clear;
clc;
close all;

dataFolder = 'C:\Sim\Dataset_tag_test\AoA_LHS_dataset\lambda3'; % složka, kde se nachází zpracovavany soubor

% NUTNO SPRAVNE NASTAVIT ROZESTUPY SOND d_ref!!
%fileName = 'AoA_lambda3_X_cs_600_Y_cs_m900_RotXY_m60_RotXZ_0_RotYZ_0.fld'; 
%fileName = 'AoA_lambda3_X_cs_600_Y_cs_600_RotXY_90_RotXZ_0_RotYZ_0.fld'; % error weighted 637,54 mm
%fileName = 'AoA_lambda3_X_cs_600_Y_cs_300_RotXY_0_RotXZ_0_RotYZ_0.fld'; % error hard 1090 mm
%fileName = 'AoA_lambda3_X_cs_m300_Y_cs_m600_RotXY_30_RotXZ_0_RotYZ_0.fld'; 
%fileName = 'AoA_lambda3_X_cs_m306_Y_cs_m235_RotXY_20_RotXZ_0_RotYZ_0.fld';
fileName = 'AoA_lambda3_X_cs_m353_Y_cs_839_RotXY_48_RotXZ_0_RotYZ_0.fld';

fullFileName = fullfile(dataFolder, fileName);

% Určení skutečné pozice z názvu
% Extrakce hodnot
% Pozice (v mm)
txt_X = extractBetween(fileName, 'X_cs_', '_Y_cs_');
txt_Y = extractBetween(fileName, 'Y_cs_', '_RotXY_');

% Natočení (ve stupních)
txt_RotXY = extractBetween(fileName, 'RotXY_', '_RotXZ_');
txt_RotXZ = extractBetween(fileName, 'RotXZ_', '_RotYZ_');
txt_RotYZ = extractBetween(fileName, 'RotYZ_', '.fld');

% Převody záporných čísel (formát "m90" -> "-90")
% Náhrada 'm' za '-' v názvech
txt_X = replace(txt_X, 'm', '-');
txt_Y = replace(txt_Y, 'm', '-');
txt_RotXY = replace(txt_RotXY, 'm', '-');
txt_RotXZ = replace(txt_RotXZ, 'm', '-');
txt_RotYZ = replace(txt_RotYZ, 'm', '-');

% Převod textu na čísla (val)
val_X_mm = str2double(txt_X);
val_Y_mm = str2double(txt_Y);
val_RotXY = str2double(txt_RotXY);
val_RotXZ = str2double(txt_RotXZ);
val_RotYZ = str2double(txt_RotYZ);

% mm ma metry skrz graf
true_X = val_X_mm / 1000;
true_Y = val_Y_mm / 1000;

fprintf('Název souboru: %s \n\n', fileName);

fprintf('Skutečná pozice [mm]:\n');
fprintf('  X: %6.1f mm \n', val_X_mm);
fprintf('  Y: %6.1f mm \n\n', val_Y_mm);

fprintf('Skutečné natočení [°]:\n');
fprintf('  RotXY: %5.1f° \n', val_RotXY);
fprintf('  RotXZ: %5.1f° \n', val_RotXZ);
fprintf('  RotYZ: %5.1f° \n\n', val_RotYZ);

%data = readmatrix(fileName, 'FileType', 'text', 'NumHeaderLines', 1);
data = readmatrix(fullFileName, 'FileType', 'text', 'NumHeaderLines', 1);

f = 915e6;
c = 3*10^8;
lambda  = c/f;  
d_ref   = lambda/3;   % vzdálenost střed–okraj - !! upravovat podle .pts !!

X_coord = data(:,1);
Y_coord = data(:,2);   
Z_coord = data(:,3);
E_real  = data(:, 4);      % Re
E_imag  = data(:, 5);      % Im

%% Výpočet fáze elektrického pole

% Výpočet fáze v radiánech - atan2(Im, Re)
% atan2 určí kvadrant (úhel od -pi do +pi)
phase_rad = atan2(E_imag, E_real);
phase_deg = rad2deg(phase_rad);

% Zobrazení výsledků
disp('Vypočtená fáze pro všechny sondy:');
disp('   Re | Im  | Phase (rad) | Phase (deg)');
disp_data = [E_real(1:20), E_imag(1:20), phase_rad(1:20), phase_deg(1:20)];
disp(disp_data);


%% Organizace dat do struktury podle čteček

% Pole struktur - každá struktura reprezentuje jednu čtečku
numReaders = 4;
numProbesPerReader = 5;

% Pre-alokace struktur
readers(numReaders) = struct('X', [], 'Y', [], 'Z', [], 'E_real', [], 'E_imag', [], 'phase_rad', []);

% Mapování indexů 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, ...
% Pro čtečku
% Index 1 = .1 (Střed)
% Index 2 = .2 (Vlevo)
% Index 3 = .3 (Vpravo)
% Index 4 = .4 (Nahoře)
% Index 5 = .5 (Dole)

probeNames = {'Střed (.1)', 'Vlevo (.2)', 'Vpravo (.3)', 'Nahoře (.4)', 'Dole (.5)'};

% Naplnění struktur daty
for i = 1:numReaders
    % Indexy řádků pro kazdou čtečku 1-5, 6-10, 11-15, 16-20
    startIndex = (i - 1) * numProbesPerReader + 1;
    endIndex = i * numProbesPerReader;

    % Data (řádky) pro 5 sond
    index = startIndex:endIndex;                   

    % Uložení dat ze seznamu do struktury - Výběr konkrétních hodnot pro konkretni sondy 
    readers(i).X = X_coord(index);            
    readers(i).Y = Y_coord(index);               
    readers(i).Z = Z_coord(index);               
    readers(i).E_real = E_real(index);           
    readers(i).E_imag = E_imag(index);           
    readers(i).phase_rad = phase_rad(index);     
    readers(i).probeNames = probeNames;             
end

% Zobrazení fáze např pro Čtečku 1
fprintf('Fáze (rad) pro Čtečku 1:\n');
for k = 1:numProbesPerReader
    fprintf('  Sonda %-12s: %f\n\n', readers(1).probeNames{k}, readers(1).phase_rad(k));
end



%% AoA

% Interval od Pi do Pi
wrapToPi = @(x) atan2(sin(x), cos(x));

for i = 1:numReaders
    
    % Prirazeni hodnot jednotlivym sondam z datoveho souboru
    phi_middle  = readers(i).phase_rad(1);      % 1 = střed
    phi_left  = readers(i).phase_rad(2);        % 2 = vlevo
    phi_right = readers(i).phase_rad(3);        % 3 = vpravo
    phi_up = readers(i).phase_rad(4);           % 4 = nahoře
    phi_bottom   = readers(i).phase_rad(5);     % 5 = dole

    % osa Y (vodorovná)
    % fázové rozdíly (okraj - střed)
    dphi_L = wrapToPi(phi_left  - phi_middle);
    dphi_R = wrapToPi(phi_right - phi_middle);

    % prumer hodnot
    delta_phi_Y = 0.5 * (dphi_R - dphi_L);

    % projekce směru na osu Y (směrový vektor)
    u_y = (lambda / (2*pi*d_ref)) * delta_phi_Y;

    % osa X (svislá)
    dphi_T = wrapToPi(phi_up - phi_middle);
    dphi_B = wrapToPi(phi_bottom   - phi_middle);

    % prumer hodnot
    delta_phi_X = 0.5 * (dphi_B - dphi_T);
    
    % projekce na osu (směrový vektor)
    u_x = (lambda / (2*pi*d_ref)) * delta_phi_X;

    % Jeden úhel od osy Y (Y vodorovně, X svisle)
    aoa_azimuth_rad = atan2(u_x, u_y);

    readers(i).AoA_azimuth_deg = rad2deg(aoa_azimuth_rad);
    readers(i).dirY = u_y;
    readers(i).dirX = u_x;

    fprintf('Čtečka %d: AoA = %.2f° (od osy Y)\n', ...
            i, readers(i).AoA_azimuth_deg);
end


%% Triangulace - fminsearch

% Standardní triangulace (Všechny váhy = 1)
initial_guess = [0, 0];
options = optimset('Display','off');

func_standard = @(point) calculate_distance_to_lines_weight(point, readers);
pos_standard = fminsearch(func_standard, initial_guess, options);

fprintf('\n Standardní fminsearch: \n');
fprintf('  Y = %.4f mm \n', pos_standard(1));
fprintf('  X = %.4f mm \n', pos_standard(2));

err_standard = sqrt((true_X - pos_standard(2))^2 + (true_Y - pos_standard(1))^2);

fprintf('  Chyba: %.1f mm \n', err_standard * 1000);

%% Predikce RF a výpočet vah
% Výpočet reziduí (vzdáleností prvotního bodu od 4 čar)
residuals_mm = zeros(1, 4);

for i = 1:numReaders
    az_rad = deg2rad(readers(i).AoA_azimuth_deg);
    uY = cos(az_rad); 
    uX = sin(az_rad);

    A = -uX; 
    B = uY; 
    C = uX*readers(i).Y(1) - uY*readers(i).X(1);

    dist_m = abs(A*pos_standard(1) + B*pos_standard(2) + C) / sqrt(A^2 + B^2);
    residuals_mm(i) = dist_m * 1000;
end

% Získání amplitud středových sond pro RF
amp_centers = zeros(1, 4);
for i = 1:numReaders
    amp_centers(i) = sqrt(readers(i).E_real(1)^2 + readers(i).E_imag(1)^2);
end

% Načtení RF modelu
load('RF_Model.mat', 'RFmodel');

% Sestavení vstupního vektoru pro RF (AoA, Res, Amp)
inputRF = [readers(1).AoA_azimuth_deg, readers(2).AoA_azimuth_deg, readers(3).AoA_azimuth_deg, readers(4).AoA_azimuth_deg, ...
           residuals_mm(1), residuals_mm(2), residuals_mm(3), residuals_mm(4), ...
           amp_centers(1), amp_centers(2), amp_centers(3), amp_centers(4)];

% Predikce - získání pravděpodobnosti z funkce pretict
[~, scores] = predict(RFmodel, inputRF);

% Výpočet vah (Váha = 1 - Pravděpodobnost, že je čtečka outlier)
rf_weights = 1 - scores(1, :); 

fprintf('\n Predikce Random Forrest: \n');
for i = 1:4

    P_err = scores(1, i)*100; % pravděpodobnost v %

    fprintf('  Čtečka %d: Pravděpodobnost chyby: %.1f %%, Váha fminsearch: %.2f \n', i, P_err, rf_weights(i));
end

%% Tvrdé vyřazení jedné čtečky
% Vložení váhy 0 čtečce, která je podle RF nejhorší
[~, outlier_idx] = min(rf_weights);

% Tvorba struktury obsahující 3 nevyřazené čtečky
valid_readers = readers(setdiff(1:numReaders, outlier_idx));

% fminsearch pro 3 nevyřazené čtečky 
func_hard = @(point) calculate_distance_to_lines_weight(point, valid_readers);
pos_hard = fminsearch(func_hard, initial_guess, options);

fprintf('\n Tvrdé vyřazení čtečky %d: \n', outlier_idx);
fprintf('  Y = %.4f mm \n', pos_hard(1));
fprintf('  X = %.4f mm \n', pos_hard(2));

err_hard = sqrt((true_X - pos_hard(2))^2 + (true_Y - pos_hard(1))^2);
fprintf('  Chyba po tvrdém vyřazení: %.1f mm \n', err_hard * 1000);

%% Vážený fminsearch (Weighted Least Squares)
% Do fminsearch stejné čtečky s přidáním vah
func_weighted = @(point) calculate_distance_to_lines_weight(point, readers, rf_weights);
pos_weighted = fminsearch(func_weighted, initial_guess, options);

% pos_weighted pro vykreslování
calculated_position_YX = pos_weighted;

fprintf('\n Vážený fminsearch s RF: \n');
fprintf('  Y = %.4f mm \n', pos_weighted(1));
fprintf('  X = %.4f mm \n', pos_weighted(2));

err_weighted = sqrt((true_X - pos_weighted(2))^2 + (true_Y - pos_weighted(1))^2);
fprintf('  Chyba s váženým fminsearch: %.1f mm\n', err_weighted * 1000);

%% Zhodnocení
if err_weighted < err_standard
    fprintf(' Random Forest zlepšil přesnost váženého fminsearch o %.1f mm vůči standardnímu fminsearch. \n', (err_standard - err_weighted)*1000);
else
    fprintf(' Random Forest zhoršil přesnost váženého fminsearc o %.1f mm vůči standardnímu fminsearch. \n', (err_weighted - err_standard)*1000);
end
%% Korekce fázové nejednoznačnosti (180° Flip)
    % Směrová polopřímka otočena pokud ukazuje pryč od vypočítaného cíle

for i = 1:numReaders
        % Vektor od středu čtečky k vypočítané poloze (v metrech)
        vY = calculated_position_YX(1) - readers(i).Y(1);
        vX = calculated_position_YX(2) - readers(i).X(1);

        % Současný směrový vektor čtečky
        az_rad = deg2rad(readers(i).AoA_azimuth_deg);
        uY = cos(az_rad);
        uX = sin(az_rad);

        % Skalární součin
        dot_product = vY * uY + vX * uX;

        if dot_product < 0
            % Vektory jdou proti sobě -> otočení o 180 stupňů
            readers(i).AoA_azimuth_deg = readers(i).AoA_azimuth_deg + 180;

            % Udržení úhlu v rozmezí -180 až 180
            if readers(i).AoA_azimuth_deg > 180
                readers(i).AoA_azimuth_deg = readers(i).AoA_azimuth_deg - 360;
            end

            fprintf('Korekce fázové nejednoznačnosti: Čtečka %d otočena o 180°.\n', i);
        end
 end

%% Vykreslení výsledků a odchylky

figure;
hold on;

tY = true_Y;                  
tX = true_X;
cY = calculated_position_YX(1);
cX = calculated_position_YX(2);

ax = gca;
ax.XAxis.FontSize = 20;
ax.YAxis.FontSize = 20;

% Výpočet chyby (Pythagorova věta, Euklidovská vzdálenost)
distance_error = sqrt((tX - cX)^2 + (tY - cY)^2);
fprintf('\n Odchylka od reality: %.1f mm \n', distance_error * 1000);

% Vykreslení prvků
% Skutečná poloha
true_tag = plot(tY, tX, 'rx', 'MarkerSize', 20, 'LineWidth', 3);

% Skutečné natočení
rot_len = 0.2;
rot_rad = deg2rad(val_RotXY);

rotY = tY + rot_len * sin(rot_rad);
rotX = tX + rot_len * cos(rot_rad);

rot_line = plot([tY, rotY], [tX, rotX], 'r-', 'LineWidth', 2);

% Čtečky a směry
for i = 1:length(readers)
    centerX = readers(i).X(1);
    centerY = readers(i).Y(1);

    reader_icon = plot(centerY, centerX, 'bs', 'MarkerSize', 20, 'MarkerFaceColor', 'blue');
    text(centerY + 0.1, centerX, sprintf('Čtečka %d', i), 'Color', 'blue', 'FontSize', 20, 'FontWeight', 'bold');

    % Čára AoA
    azimuth_rad = deg2rad(readers(i).AoA_azimuth_deg);
    lineLength = 5; 

    vec_Y = lineLength * cos(azimuth_rad);
    vec_X = lineLength * sin(azimuth_rad);

    endY = centerY + vec_Y;
    endX = centerX + vec_X;

    line_icon = plot([centerY, endY], [centerX, endX], 'g-', 'LineWidth', 2);
end

% Chybová úsečka
error_line = plot([tY, cY], [tX, cX], 'm--', 'LineWidth', 2);

% Vypočítaná poloha tagu
calculated_position = plot(cY, cX, 'ko', 'MarkerSize', 20, 'LineWidth', 2, 'MarkerFaceColor', 'black');

% Text chybové čáry
text((tY + cY)/2, (tX + cX)/2, sprintf(' %.0f mm', distance_error * 1000), ...
     'Color', 'm', 'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

% Název souboru
[~, fName, fExt] = fileparts(fileName); 
displayName = [fName, fExt];

% Nastavení grafu
grid on;
axis equal;
xlim([-1.5, 1.5]); 
ylim([-1, 1.25]);
xlabel('Osa Y [m]', 'FontSize', 20);
ylabel('Osa X [m]', 'FontSize', 20);

% Titulek
title({['AoA Fminsearch: ', strrep(displayName, '_', '\_')], ...
       sprintf('Chyba s váženým fminsearch: %.1f mm', distance_error * 1000)}, 'FontSize', 20 );

legend([reader_icon, line_icon, true_tag, rot_line, calculated_position, error_line], ...
       {'Střed čtečky', 'Vypočítaný směr AoA', 'Skutečná poloha', 'Směr natočení tagu', 'Odhadnutá poloha', 'Chybová vzdálenost'}, ...
       'Location', 'best', 'FontSize', 20);

set(gca, 'YDir', 'reverse'); % +X směřuje dolů
hold off;