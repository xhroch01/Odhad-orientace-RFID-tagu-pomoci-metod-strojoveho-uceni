% hledání pomocí metody průsečíků 

clear;
clc;
close all;

%% Načítání dat

fileName = 'sem vložit cestu a název testovaného souboru'; % NUTNO SPRAVNE NASTAVIT ROZESTUPY SOND d_ref!!

% Získání skutečné polohy z názvu
% Extrakce hodnot
txt_X = extractBetween(fileName, 'X_cs_', '_Y_cs_');
txt_Y = extractBetween(fileName, 'Y_cs_', '_RotXY_');
txt_RotXY = extractBetween(fileName, 'RotXY_', '_RotXZ_');
txt_RotXZ = extractBetween(fileName, 'RotXZ_', '_RotYZ_');
txt_RotYZ = extractBetween(fileName, 'RotYZ_', '.fld');

% Převod 'm' jako mínus
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

% Přepočet na metry (pro graf a výpočty)
true_X = val_X_mm / 1000;
true_Y = val_Y_mm / 1000;

fprintf('Zpracovávaný soubor: %s\n', fileName);
fprintf('\n Skutečná pozice: X=%.1f mm, Y=%.1f mm\n', val_X_mm, val_Y_mm);
fprintf('\n Skutečné natočení: XY=%.1f°, XZ=%.1f°, YZ=%.1f°\n\n', val_RotXY, val_RotXZ, val_RotYZ);

data = readmatrix(fileName, 'FileType', 'text', 'NumHeaderLines', 1);

f = 915e6;
c = 3*10^8;
lambda  = c/f;  
d_ref   = lambda/3;   % vzdálenost střed–okraj - !! upravovat podle .pts !!

X_coord = data(:,1);
Y_coord = data(:,2); 
Z_coord = data(:,3);
E_real  = data(:, 4);
E_imag  = data(:, 5);

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

% Pole struktur - každá struktura určuje jednu čtečku
numReaders = 4;
numProbesPerReader = 5;

% Pre-alokace struktur
readers(numReaders) = struct('X', [], 'Y', [], 'Z', [], 'E_real', [], 'E_imag', [], 'phase_rad', []);

% Mapování indexů 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, ...
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

% fáze pro Čtečku 1
fprintf('Fáze (rad) pro Čtečku 1:\n');
for k = 1:numProbesPerReader
    fprintf('  Sonda %-12s: %f\n', readers(1).probeNames{k}, readers(1).phase_rad(k));
end



%% AoA

% Interval od -Pi do Pi
% @(x) syntax pro zkrácení zápisu - nemusí být speciální function
WrapToPi = @(x) atan2(sin(x), cos(x));

for i = 1:numReaders
    
    % Přiřazení hodnot jednotlivým sondam z datoveho souboru
    phi_middle  = readers(i).phase_rad(1);  % 1 = střed
    phi_left  = readers(i).phase_rad(2);    % 2 = vlevo
    phi_right = readers(i).phase_rad(3);    % 3 = vpravo
    phi_up = readers(i).phase_rad(4);       % 4 = nahoře
    phi_bottom   = readers(i).phase_rad(5); % 5 = dole

    % osa Y (vodorovná)
    % fázové rozdíly (okraj - střed)
    dphi_L = WrapToPi(phi_left - phi_middle);
    dphi_R = WrapToPi(phi_right - phi_middle);

    % průměr hodnot
    delta_phi_Y = 0.5 * (dphi_R - dphi_L);

    % projekce směru na osu Y (směrový vektor)
    u_y = (lambda / (2*pi*d_ref)) * delta_phi_Y;

    % osa X (svislá) 
    dphi_T = WrapToPi(phi_up - phi_middle);
    dphi_B = WrapToPi(phi_bottom - phi_middle);

    % prumer hodnot
    delta_phi_X = 0.5 * (dphi_B - dphi_T);
    
    % projekce na osu (směrový vektor)
    u_x = (lambda / (2*pi*d_ref)) * delta_phi_X;

    % úhel od osy Y (Y vodorovně, X svisle)
    AoA_azimuth_rad = atan2(u_x, u_y);

    readers(i).AoA_azimuth_deg = rad2deg(AoA_azimuth_rad);
    readers(i).dirY = u_y;
    readers(i).dirX = u_x;

    fprintf('\n Čtečka %d: AoA = %.2f° (od osy Y)', ...
            i, readers(i).AoA_azimuth_deg);
end

%% Triangulace - Metoda průsečíků přímek (Intersection of Lines)
% převedení úhlu na přímku 

% Předpřipravení polí pro koeficienty
a_coef = zeros(1, numReaders);
b_coef = zeros(1, numReaders);
c_coef = zeros(1, numReaders);

for i = 1:numReaders
    angle_deg = readers(i).AoA_azimuth_deg;
    angle_rad = deg2rad(angle_deg);
    
    % Výpočet normálového vektoru přímky (kolmý na směr AoA)
    % Pokud směr vektoru (cos, sin), normálový vektor je (-sin, cos)
    val_a = -sin(angle_rad);
    val_b =  cos(angle_rad);
    
    % Dosazení souřadnic středu čtečky pro výpočet c
    % c = a*y + b*x
    center_y = readers(i).Y(1);
    center_x = readers(i).X(1);
    val_c = val_a * center_y + val_b * center_x;
    
    % Uložení do polí
    a_coef(i) = val_a;
    b_coef(i) = val_b;
    c_coef(i) = val_c;
end

% Testy skupin po 3 (najde trojúhelníky) - všechny kombinace
% Hledá skupinu s nejmenší chybou (nejmenší rozptyl průsečíků).

combinations = nchoosek(1:numReaders, 3); % seznam kombinací (1-2-3, 1-2-4...)
num_combs = size(combinations, 1);

min_error = 1000000;  % velká počáteční chyba (nekonečno)
final_y = 0;
final_x = 0;

for k = 1:num_combs
    % Načtení indexů aktuální trojice, např. [1, 2, 3]
    idx_vec = combinations(k, :);
    
    % Hledání 3 průsečíků (čtečka 1-2, 1-3, 2-3)

    % Dvojice 1-2
    idx1 = idx_vec(1);
    idx2 = idx_vec(2);
    
    % Řešení soustavy rovnic
    [py1, px1] = solve_intersection(a_coef, b_coef, c_coef, idx1, idx2);
    
    % Dvojice 1-3
    idx1 = idx_vec(1);
    idx3 = idx_vec(3);
    [py2, px2] = solve_intersection(a_coef, b_coef, c_coef, idx1, idx3);
    
    % Dvojice 2-3
    idx2 = idx_vec(2);
    idx3 = idx_vec(3);
    [py3, px3] = solve_intersection(a_coef, b_coef, c_coef, idx2, idx3);
    
    % Uložení bodů do seznamu
    pts_y = [py1, py2, py3];
    pts_x = [px1, px2, px3];
    
    % Výpočet středu (těžiště) 3 bodů každého trojúhelníku
    mean_y = mean(pts_y);
    mean_x = mean(pts_x);
    
    % velikost trojúhelníku = součet vzdáleností bodů od středu
    dist1 = sqrt((pts_y(1) - mean_y)^2 + (pts_x(1) - mean_x)^2);
    dist2 = sqrt((pts_y(2) - mean_y)^2 + (pts_x(2) - mean_x)^2);
    dist3 = sqrt((pts_y(3) - mean_y)^2 + (pts_x(3) - mean_x)^2);
    
    total_error = dist1 + dist2 + dist3;
    
    % Pokud je chyba menší než aktuální minimum, uloží výsledek
    if total_error < min_error
        min_error = total_error;
        final_y = mean_y;
        final_x = mean_x;
    end
end

% Uložení výsledku pro vykreslení
calculated_position_YX = [final_y, final_x];

fprintf('\n\nVýsledná poloha: \nY = %.4f mm \nX = %.4f mm\n', final_y, final_x);

% Funkce pro řešení soustavy rovnic
function [y, x] = solve_intersection(a, b, c, i1, i2)
    % Rovnice 1: a(i1)*y + b(i1)*x = c(i1)
    % Rovnice 2: a(i2)*y + b(i2)*x = c(i2)
    
    % Sestavení matice soustavy
    Matrix = [a(i1), b(i1); 
              a(i2), b(i2)];
         
    Right = [c(i1); 
             c(i2)];
    
    % Soustava rovnic (matice \ pravá strana)
    result = Matrix \ Right;
    
    y = result(1);
    x = result(2);
end

%% 6. Vykreslení výsledků

figure;
hold on;

% Proměnné pro přehlednost
tY = true_Y; 
tX = true_X;               
cY = calculated_position_YX(1);         
cX = calculated_position_YX(2);

% Výpočet chyby (Pythagorova věta, Euklidovská vzdálenost)
distance_error = sqrt((tX - cX)^2 + (tY - cY)^2);
fprintf('\nOdchylka od reality: \n%.1f mm\n', distance_error * 1000);

% Skutečná poloha
true_tag = plot(tY, tX, 'rx', 'MarkerSize', 15, 'LineWidth', 3);

% Skutečné natočení
rot_len = 0.2;
rot_rad = deg2rad(val_RotXY);

rotY = tY + rot_len * sin(rot_rad);
rotX = tX + rot_len * cos(rot_rad);

rot_line = plot([tY, rotY], [tX, rotX], 'r-', 'LineWidth', 2);

% Čtečky a AoA
for i = 1:length(readers)
    rY = readers(i).Y(1);
    rX = readers(i).X(1);
    az = deg2rad(readers(i).AoA_azimuth_deg);
    
    % Čtečka
    reader_icon = plot(rY, rX, 'bs', 'MarkerSize', 15, 'MarkerFaceColor', 'blue');
    text(rY + 0.1, rX, sprintf('Čtečka %d', i), 'Color', 'blue', 'FontSize', 12);
    
    % Čára AoA
    line_icon = plot([rY, rY+10*cos(az)], [rX, rX+10*sin(az)], 'g-', 'LineWidth', 2);
end

% Chybová úsečka
error_line = plot([tY, cY], [tX, cX], 'm--', 'LineWidth', 1.5);

% Vypočítaná poloha
calculated_pos = plot(cY, cX, 'ko', 'MarkerSize', 12, 'LineWidth', 2, 'MarkerFaceColor', 'black');

% Text odchylky
text((tY+cY)/2, (tX+cX)/2, sprintf(' %.0f mm', distance_error*1000), ...
     'Color', 'm', 'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');

% Název souboru
[~, fName, fExt] = fileparts(fileName); 
displayName = [fName, fExt];

grid on; 
axis equal;
xlim([-1.5, 1.5]); 
ylim([-1, 1.25]);
xlabel('Osa Y'); ylabel('Osa X');
title({['AoA Intersection: ', strrep(displayName, '_', '\_')], ...
       sprintf('Chyba: %.1f mm', distance_error*1000)});

legend([reader_icon, line_icon, true_tag, rot_line, calculated_pos, error_line], ...
       {'Střed čtečky', 'Vypočítaný směr AoA', 'Skutečná poloha', 'Směr natočení tagu', 'Odhadnutá poloha', 'Chyba'}, ...
       'Location', 'best');

set(gca, 'YDir', 'reverse'); % +X dolů

hold off;