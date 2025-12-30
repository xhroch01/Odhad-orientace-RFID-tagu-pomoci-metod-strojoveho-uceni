% hledání pomocí funkce fminsearch
%% Načtení dat

clear;
clc;
close all;

fileName = 'sem vložit cestu a název testovaného souboru'; % NUTNO SPRAVNE NASTAVIT ROZESTUPY SOND d_ref!!

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

data = readmatrix(fileName, 'FileType', 'text', 'NumHeaderLines', 1);

f  =915e6;
c = 3*10^8;
lambda  = c/f;  
d_ref   = lambda/4;   % vzdálenost střed–okraj - !! upravovat podle .pts !!

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

% Vychozi bod pro hledání [Y, X]
initial_guess = [0, 0];

% Triangulační funkce - výpočet nejmenší vzdálenosti
% readers - fixní data, point - hledaná data, která se mění a předávají dál
% označená @(point)
triangulation_function = @(point) calculate_distance_to_lines(point, readers);

% Nastavení vypnutí vypisu stavu hledání nejmenší vzdálenosti
options = optimset('Display','off');

calculated_position_YX = fminsearch(triangulation_function, initial_guess, options);

% Výsledek
fprintf('\nVýsledná poloha:\n');
fprintf('  Y = %.4f mm\n', calculated_position_YX(1));
fprintf('  X = %.4f mm\n', calculated_position_YX(2));

%% Vykreslení výsledků a odchylky

figure;
hold on;

tY = true_Y;                  
tX = true_X;
cY = calculated_position_YX(1);
cX = calculated_position_YX(2);

% Výpočet chyby (Pythagorova věta, Euklidovská vzdálenost)
distance_error = sqrt((tX - cX)^2 + (tY - cY)^2);
fprintf('\nOdchylka od reality: %.1f mm \n', distance_error * 1000);

% Vykreslení prvků
% Skutečná poloha
true_tag = plot(tY, tX, 'rx', 'MarkerSize', 15, 'LineWidth', 3);

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

    reader_icon = plot(centerY, centerX, 'bs', 'MarkerSize', 15, 'MarkerFaceColor', 'blue');
    text(centerY + 0.1, centerX, sprintf('Čtečka %d', i), 'Color', 'blue', 'FontSize', 12);

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
error_line = plot([tY, cY], [tX, cX], 'm--', 'LineWidth', 1.5);

% Vypočítaná poloha tagu
calculated_position = plot(cY, cX, 'ko', 'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'black');

% Text chybové čáry
text((tY + cY)/2, (tX + cX)/2, sprintf(' %.0f mm', distance_error * 1000), ...
     'Color', 'm', 'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

% Název souboru
[~, fName, fExt] = fileparts(fileName); 
displayName = [fName, fExt];

% Nastavení grafu
grid on;
axis equal;
xlim([-1.5, 1.5]); 
ylim([-1, 1.25]);
xlabel('Osa Y');
ylabel('Osa X');

% Titulek
title({['AoA Fminsearch: ', strrep(displayName, '_', '\_')], ...
       sprintf('Chyba: %.1f mm', distance_error * 1000)});

legend([reader_icon, line_icon, true_tag, rot_line, calculated_position, error_line], ...
       {'Střed čtečky', 'Vypočítaný směr AoA', 'Skutečná poloha', 'Směr natočení tagu', 'Odhadnutá poloha', 'Chybová vzdálenost'}, ...
       'Location', 'best');

set(gca, 'YDir', 'reverse'); % +X směřuje dolů
hold off;