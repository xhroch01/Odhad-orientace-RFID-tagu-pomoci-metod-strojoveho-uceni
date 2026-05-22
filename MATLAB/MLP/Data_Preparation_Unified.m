clear; 
clc;

path_LHS = 'C:\Sim\Dataset_tag_test\AoA_LHS_dataset\lambda3'; 
path_Grid = 'C:\Sim\Dataset_tag_test\AoA_grid_dataset\Grid_prostor_lambda3';

% seznamy souborů
files_LHS = dir(fullfile(path_LHS, 'AoA_lambda3_*.fld'));
files_Grid = dir(fullfile(path_Grid, 'AoA_lambda3_*.fld'));

% Spojení datasetů
all_files = [files_LHS; files_Grid]; 
numFiles = length(all_files);

fprintf('Celkem %d souborů (LHS + Grid) \n', numFiles);

% Inicializace matic
X_all = zeros(40, numFiles);
Y_all = zeros(4, numFiles);

for i = 1:numFiles
    file = all_files(i);
    fname = file.name;
    folder = file.folder;
    
    % Parsování názvu
    txt_X = extractBetween(fname, 'X_cs_', '_Y_cs_');
    txt_Y = extractBetween(fname, 'Y_cs_', '_RotXY_');
    txt_RotXY = extractBetween(fname, 'RotXY_', '_RotXZ_');
    
    val_X_mm = str2double(replace(txt_X, 'm', '-'));
    val_Y_mm = str2double(replace(txt_Y, 'm', '-'));
    val_RotXY = str2double(replace(txt_RotXY, 'm', '-'));
    
    % Načtení dat (vstupy)
    data = readmatrix(fullfile(folder, fname), 'FileType', 'text', 'NumHeaderLines', 1);
    
    % Proložení Re a Im
    temp_in = zeros(40, 1);
    temp_in(1:2:end) = data(:, 4); % Re
    temp_in(2:2:end) = data(:, 5); % Im
    X_all(:, i) = temp_in;
    
    % Uložení výsledků
    phi_rad = deg2rad(val_RotXY);
    Y_all(:, i) = [val_X_mm/1000; val_Y_mm/1000; cos(phi_rad); sin(phi_rad)]; % skutečná poloha X, Y a cos a sin úhlu
end

% Transpozice matic
X_all = X_all'; 
Y_all = Y_all';

save('Unified_Lambda3_Data.mat', 'X_all', 'Y_all');