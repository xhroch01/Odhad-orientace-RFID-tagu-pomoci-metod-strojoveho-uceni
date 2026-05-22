%% Vyhodnocení a logika WKNN - kNN nebo buňky se vybírají v single run nebo loop sktipru

function [est_rot, true_rot, err_deg, info] = WKNN_rotation_estimate(fileName, Database, RFmodel, K, mode)
% mode: 'wknn'   - K nejbližších uzlů (default)
%       'cell' - 4 rohy obklopující buňky gridu
if nargin < 5
    mode = 'wknn';
end

%% Parametry

idw_power = 2; % pokles váhy se vzdáleností
numReaders = 4;

f = 915e6;
c = 3e8;
lambda = c/f;
d_ref = lambda/3;   % NUTNO NASTAVIT PODLE POUŽITÉHO GRIDU A ZPRACOVÁVANÝCH DAT

wrapToPi = @(x) atan2(sin(x), cos(x));

%% Skutečná poloha z názvu souboru pro testované vzorky
[~, base, ~] = fileparts(fileName);

txt_X     = replace(extractBetween(base, 'X_cs_',  '_Y_cs_'),  'm', '-');
txt_Y     = replace(extractBetween(base, 'Y_cs_',  '_RotXY_'), 'm', '-');
txt_RotXY = replace(extractBetween(base, 'RotXY_', '_RotXZ_'), 'm', '-');

true_X    = str2double(txt_X);
true_Y    = str2double(txt_Y);
true_rot  = str2double(txt_RotXY);

%% Načtení dat a výpočet AoA
data = readmatrix(fileName, 'FileType', 'text', 'NumHeaderLines', 1);

X_coord = data(:,1); 
Y_coord = data(:,2);
E_real  = data(:,4); 
E_imag  = data(:,5);

E_meas_cplx = complex(E_real, E_imag);
phase_rad   = atan2(E_imag, E_real);

readers(numReaders) = struct('X',[],'Y',[],'AoA_azimuth_deg',[]);
for i = 1:numReaders

    idx = ((i-1)*5+1):(i*5);
    readers(i).X = X_coord(idx);
    readers(i).Y = Y_coord(idx);

    phi_mid = phase_rad(idx(1));
    dphi_L  = wrapToPi(phase_rad(idx(2)) - phi_mid);
    dphi_R  = wrapToPi(phase_rad(idx(3)) - phi_mid);
    dphi_T  = wrapToPi(phase_rad(idx(4)) - phi_mid);
    dphi_B  = wrapToPi(phase_rad(idx(5)) - phi_mid);

    u_y = (lambda/(2*pi*d_ref)) * 0.5*(dphi_R - dphi_L);
    u_x = (lambda/(2*pi*d_ref)) * 0.5*(dphi_B - dphi_T);

    readers(i).AoA_azimuth_deg = rad2deg(atan2(u_x, u_y));
end

%% Lokalizace (Standard -> RF -> Soft fminsearch)
opts = optimset('Display','off');
pos_standard = fminsearch(@(p) calculate_distance_to_lines_weight(p, readers), [0 0], opts);

residuals_mm = zeros(1, numReaders);
amp_centers  = zeros(1, numReaders);
for i = 1:numReaders

    az = deg2rad(readers(i).AoA_azimuth_deg);

    A = -sin(az); 
    B = cos(az);
    C = sin(az)*readers(i).Y(1) - cos(az)*readers(i).X(1);

    residuals_mm(i) = abs(A*pos_standard(1)+B*pos_standard(2)+C)/sqrt(A^2+B^2)*1000;
    amp_centers(i)  = sqrt(E_real((i-1)*5+1)^2 + E_imag((i-1)*5+1)^2);

end

inputRF = [readers(1).AoA_azimuth_deg, readers(2).AoA_azimuth_deg, ...
           readers(3).AoA_azimuth_deg, readers(4).AoA_azimuth_deg, ...
           residuals_mm, amp_centers];

[~, scores]  = predict(RFmodel, inputRF);
rf_weights   = 1 - scores(1, :);
pos_weighted = fminsearch(@(p) calculate_distance_to_lines_weight(p, readers, rf_weights), [0 0], opts);

est_Y_mm = pos_weighted(1)*1000;
est_X_mm = pos_weighted(2)*1000;

%% Výběr uzlů mřížky

% Všechny body z mřížky
db_X = [Database.X]';
db_Y = [Database.Y]';

% Výběr konkrétních nejbližších bodů
unique_nodes = unique([db_X, db_Y], 'rows');

node_X = unique_nodes(:,1);
node_Y = unique_nodes(:,2);

% Euklidovská vzdálenost mezi odhadem polohy a nejbližšími uzly
geo_dist_nodes = sqrt((node_X - est_X_mm).^2 + (node_Y - est_Y_mm).^2);

% Rozdělení výběru referenčních bodů na 4 nejbližší body a konkrétní buňku
switch mode
    % pro K nejbližšéch bodů
    case 'wknn'
        [~, sort_geo] = sort(geo_dist_nodes, 'ascend');
        knn_idx = sort_geo(1:K); %pro prvních K indexů

    % pro jakýkoliv grid hodnot (nepravidelná tensorová mřížka)
    case 'cell'
        K = 4;  % přepíše se, kdyby bylo pro kNN definováno jinak

        % Všechny vzestupně seřazené X-souřadnice a Y-souřadnice
        grid_X = unique(node_X);
        grid_Y = unique(node_Y);

        % Nalezení sousedních X-hodnot, mezi kterými leží est_X_mm
        ix_lo = find(grid_X <= est_X_mm, 1, 'last'); % 1 = kolik indexů se má najít
        ix_hi = find(grid_X >= est_X_mm, 1, 'first');

        % Nalezení sousedních Y-hodnot, mezi kterými leží est_Y_mm
        iy_lo = find(grid_Y <= est_Y_mm, 1, 'last');
        iy_hi = find(grid_Y >= est_Y_mm, 1, 'first');

        % 4 rohy (uzly) obklopujícího obdélníku
        corners = [grid_X(ix_lo), grid_Y(iy_lo);
                   grid_X(ix_hi), grid_Y(iy_lo);
                   grid_X(ix_lo), grid_Y(iy_hi);
                   grid_X(ix_hi), grid_Y(iy_hi)];

        knn_idx = zeros(4, 1);

        for c = 1:4

            match = find(node_X == corners(c,1) & node_Y == corners(c,2), 1);

            knn_idx(c) = match;
        end        
end

%% Lokální virtuální fingerprinting v úhlu

% prealokace struktury
est_ang_per_node  = zeros(K, 1); % Odhad úhlu v konkrétním uzlu
min_cost_per_node = zeros(K, 1); % Shoda nejlepšího úhlu s měřením 

for n = 1:K

    % vytažení dat pro jeden konkrétní uzel
    nX = node_X(knn_idx(n)); %souřadnice uzlu
    nY = node_Y(knn_idx(n));

    nodedata = Database(db_X == nX & db_Y == nY); %všechna příslušná data pro příslušný uzel

    % seřazení dat podle úhlu (s_ = sorted)
    [s_ang, si] = sort([nodedata.RotXY]);
    s_cplx      = [nodedata(si).Fingerprint_Cplx];

    % Interpolace (Re a Im zjemní krok natočení z 10° na 1°)
    fine_angles = -90:1:90; % hustota virtuálního fingerprintu
    Re_i = zeros(20, numel(fine_angles)); 
    Im_i = zeros(20, numel(fine_angles));

    for p = 1:20
        Re_i(p,:) = interp1(s_ang, real(s_cplx(p,:)), fine_angles, 'linear');
        Im_i(p,:) = interp1(s_ang, imag(s_cplx(p,:)), fine_angles, 'linear');
    end

    % Virtuální fingerprint
    virt_fprints = complex(Re_i, Im_i);

    % celková chyba pro každý z možných úhlů
    error = zeros(1, numel(fine_angles));

    % Výpočet (ne)podobnosti mezi měřeným a simulovaným fingerprintem 
    % přes úhly a čtečky
    for a = 1:numel(fine_angles)
        total = 0; %akumulace chyby přes čtečky v rámci příhodného úhlu
        for r = 1:numReaders
            idx_s = ((r-1)*5+1):(r*5); % indexy 5 sond jedné čtečky
            vm = E_meas_cplx(idx_s); % měřený vektor
            vv = virt_fprints(idx_s, a); % virtualální vektor
            cos_vec = abs(dot(vm, vv)) / (norm(vm)*norm(vv) + 1e-12); % Kosinova podobnost vektorů, abs vyřadí fázi
            total = total + (1 - cos_vec); % Úhlová vzdálenost 
        end
        error(a) = total;
    end

    % Výběr nejlepšího úhlu v uzlu, min = minimální hodnota, m_index =
    % min-index
    [min_cost_per_node(n), m_index] = min(error); % min chyba
    est_ang_per_node(n) = fine_angles(m_index); % odpovídající úhel
end

%% Vážený kruhový průměr (s periodou 180°)
if K == 1   % pro K=1 není co počítat => poloha = bod z gridu (ošetření)
    est_rot = est_ang_per_node(1);
    w = 1;

else
    % w_geo = váha podle geo blízkosti, geo_dist=vzdálenost pro K uzlů
    w_geo = 1 ./ (geo_dist_nodes(knn_idx).^idw_power + 1e-9); 

    % váha podle kvality uzlu => nalezený lokální úhel v uzlu odpovídá s měřením, má vyšší váhu
    w_fit = 1 ./ (min_cost_per_node + 1e-9);

    % podmínka - uzel musí být blízko a mít dobrý fit
    w = w_geo .* w_fit;

    % výpočet pravděpodobnosti
    w = w / sum(w);

    ang_rad2 = deg2rad(2 * est_ang_per_node);
    est_rot  = 0.5 * rad2deg(atan2(sum(w.*sin(ang_rad2)), sum(w.*cos(ang_rad2))));
end

% půlkruhová chyba (wraptopi od -90 do +90)
err_deg = mod(true_rot - est_rot + 90, 180) - 90;

%% Příprava pro vizualizaci
info.readers            = readers;
info.pos_weighted       = pos_weighted;
info.true_X             = true_X;
info.true_Y             = true_Y;
info.node_X             = node_X;
info.node_Y             = node_Y;
info.knn_idx            = knn_idx;
info.est_ang_per_node   = est_ang_per_node;
info.min_cost_per_node  = min_cost_per_node;
info.w                  = w;
end