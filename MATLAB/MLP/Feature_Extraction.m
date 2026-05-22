clear; 
clc;

%% Načtení dat
load('Unified_Lambda3_Data.mat');
numSamples = size(X_all, 1);

fprintf('Načteno %d vzorků \n', numSamples);

%% Rozdělení na Re a Im
% POZN. X_all - 40 sloupců: [Re1, Im1, Re2, Im2, ..., Re20, Im20]
X_Re = X_all(:, 1:2:end); % liché sloupce (20 sloupců)
X_Im = X_all(:, 2:2:end); % sudé sloupce (20 sloupců)

%% Výpočet Amplitudy a absolutní Fáze
X_Amp = sqrt(X_Re.^2 + X_Im.^2);
X_Phase = atan2(X_Im, X_Re); % Fáze v radiánech (-pi až pi)

%% Výpočet Fázových rozdílů (rozdíly mezi sondami)
X_PhaseDiff_4 = zeros(numSamples, 16); % 4 čtečky * 4 rozdíly = 16 sloupců
col_idx = 1;

for reader = 1:4
    idx_center = (reader - 1) * 5 + 1; 
    idx_others = idx_center + (1:4);   

    % Fáze okolní - Fáze středová
    X_PhaseDiff_4(:, col_idx:col_idx+3) = wrapToPi(X_Phase(:, idx_others) - X_Phase(:, idx_center));
    col_idx = col_idx + 4;
end

%% Výpočet fázových gradientů (průměr fázových rozdílů mezi páry sond)
X_PhaseDiff_Grad = zeros(numSamples, 8); % 4 čtečky * 2 osy = 8 sloupců
col_idx = 1;
for reader = 1:4
    idx_center = (reader - 1) * 5 + 1;
    idx_Left   = idx_center + 1;
    idx_Right  = idx_center + 2;
    idx_Top    = idx_center + 3;
    idx_Bottom = idx_center + 4;

    phi_middle = X_Phase(:, idx_center);
    phi_left   = X_Phase(:, idx_Left);
    phi_right  = X_Phase(:, idx_Right);
    phi_top    = X_Phase(:, idx_Top);
    phi_bottom = X_Phase(:, idx_Bottom);

    dphi_Left   = wrapToPi(phi_left   - phi_middle);
    dphi_Right  = wrapToPi(phi_right  - phi_middle);
    dphi_Top    = wrapToPi(phi_top    - phi_middle);
    dphi_Bottom = wrapToPi(phi_bottom - phi_middle);

    delta_phi_Y = 0.5 * wrapToPi(dphi_Right - dphi_Left);
    delta_phi_X = 0.5 * wrapToPi(dphi_Bottom - dphi_Top);

    X_PhaseDiff_Grad(:, col_idx)   = delta_phi_Y;
    X_PhaseDiff_Grad(:, col_idx+1) = delta_phi_X;
    
    col_idx = col_idx + 2;
end

%% Vstupní matice pro srovnání
Dataset_ReIm             = X_all;                        % 40 features
Dataset_AmpPhase         = [X_Amp, X_Phase];             % 40 features

Dataset_ReImAmp          = [X_all, X_Amp];               % 60 features
Dataset_ReImPhase        = [X_all, X_Phase];             % 60 features
Dataset_ReImAmpPhase     = [X_all, X_Amp, X_Phase];      % 80 features

Dataset_PhaseDiff        = X_PhaseDiff_4;                % 16 features - fázové rozdíly mezi jednotlivými sondami ve čtečce
Dataset_Amp_PhaseDiff    = [X_Amp, X_PhaseDiff_4];       % 36 features 

Dataset_PhaseGrad        = X_PhaseDiff_Grad;             % 8 features - gradienty mezi páry čteček
Dataset_Amp_Grad         = [X_Amp, X_PhaseDiff_Grad];    % 28 features

%% Uložení vstupních matic
save('Features_Lambda3.mat', 'Y_all', ...
    'Dataset_ReIm', 'Dataset_AmpPhase', 'Dataset_ReImAmp', ...
    'Dataset_ReImPhase', 'Dataset_ReImAmpPhase', ...
    'Dataset_PhaseDiff', 'Dataset_Amp_PhaseDiff', ...
    'Dataset_PhaseGrad', 'Dataset_Amp_Grad');
