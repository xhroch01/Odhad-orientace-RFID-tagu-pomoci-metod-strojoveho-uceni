%% Základní augmentace s AWGN a RANDN šumu pomocí smyčky
clear; 
clc;

rng(42, 'twister');

%% Načtení datasetu
load('Features_Lambda3.mat', 'Dataset_Amp_PhaseDiff', 'Y_all');

X_orig = Dataset_Amp_PhaseDiff;
Y_orig = Y_all;
numSamples = size(X_orig, 1);

fprintf('Načteno %d originálních vzorků \n', numSamples);

% Rozdělení - Amplituda (sloupce 1-20), Fázové rozdíly (sloupce 21-36)
X_Amp_orig = X_orig(:, 1:20);
X_Phase_orig = X_orig(:, 21:36);

%% Generování zašuměných sad
% Úrovně šumu (SNR pro amplitudu, Stupně pro fázi)
SNR_levels    = [25,  20,  20,  18,  15];  % Odstup signálu od šumu (menší = víc šumu)
phase_std_deg = [1.5, 3.0, 3.0, 4.0, 5.0]; % Směrodatná odchylka fázového šumu ve stupních

% Základem finálního datasetu jsou originální data pro pozdejší použití
X_Train_Augmented = X_orig;
Y_Train_Augmented = Y_orig;

% projde originální data a přidá jinou úroveň šumu podle SNR_levels
for i = 1:length(SNR_levels)
    
    % Šum do Amplitudy
    X_Amp_noisy = awgn(X_Amp_orig, SNR_levels(i), 'measured');
    X_Amp_noisy(X_Amp_noisy < 0) = 0; % Amplituda nesmí být záporná
    
    % Šum do Fáze
    Noise_phase = randn(numSamples, 16) * deg2rad(phase_std_deg(i));
    X_Phase_noisy = wrapToPi(X_Phase_orig + Noise_phase); % Ošetření přetečení fází (-pi až pi)
    
    % Spojení Amplitudy a Fáze
    X_noisy = [X_Amp_noisy, X_Phase_noisy];
    
    % Přidání zašuměné sady na konec datasetu
    X_Train_Augmented = [X_Train_Augmented; X_noisy];
    Y_Train_Augmented = [Y_Train_Augmented; Y_orig]; % Cílové souřadnice jsou stále stejné
end

totalSamples = size(X_Train_Augmented, 1);

%% Uložení
save('Augmented_Dataset_Amp_PhaseDiff_Lambda3.mat', 'X_Train_Augmented', 'Y_Train_Augmented');

fprintf('\n Počet vzorků po augmentaci: %d ; původní počet %d\n', totalSamples, numSamples);
