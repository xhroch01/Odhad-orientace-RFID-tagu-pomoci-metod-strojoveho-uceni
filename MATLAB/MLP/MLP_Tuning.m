%% Základní tuning - hledání prvotní nejlepší architektury
% po nalezení hyperparametrů druhý běh - nastavit aktivační funkci + hodnoty batch, learning rate a L2
% Skript je volán ze startovacího skriptu Start_Tuning.m
% spustit ve složce ...\PlatEMO\PlatEMO-master\PlatEMO-master\PlatEMO

classdef MLP_Tuning < PROBLEM

    % Vlastnosti třídy
    properties(Access = private)

        XTrain; 
        YTrain; 
        XVal; 
        YVal; 
        XTest; % použito až ve finálním modelu
        YTest; % použito až ve finálním modelu
        numFeatures;

        % Počítadlo výpisu
        evalCount = 0; 
    end

    methods
        function Setting(obj)
            % Rozhodovací prostor a meze
            obj.M = 1; 
            obj.D = 4; % [Vrstvy, N1, N2, N3]
            obj.encoding = [2, 2, 2, 2]; % 1=real, 2=integer
            obj.lower = [1,  16,  16,  16]; 
            obj.upper = [3, 256, 256, 256];

            % Načtení dat a Anti-Leakage Split
            load('Augmented_Dataset_Amp_PhaseDiff_Lambda3.mat', 'X_Train_Augmented', 'Y_Train_Augmented'); 
            num_orig = 1304; 
            rng(42, 'twister'); 

            % Zamíchání hodnot v datasetu
            idx_base = randperm(num_orig); 

            % Rozdělení dat na trénink, validaci a test
            numTrain_base = floor(0.70 * num_orig);
            numVal_base   = floor(0.15 * num_orig);

            idxTrain_base = idx_base(1:numTrain_base);
            idxVal_base   = idx_base(numTrain_base+1 : numTrain_base+numVal_base);
            idxTest_base  = idx_base(numTrain_base+numVal_base+1 : end);

            % Určení původních dat + jejich augmentované klony
            expand_idx = @(base) [base, base+num_orig, base+2*num_orig, base+3*num_orig, base+4*num_orig, base+5*num_orig];

            idxTrain = expand_idx(idxTrain_base);
            idxVal   = expand_idx(idxVal_base);
            idxTest  = expand_idx(idxTest_base);

            XTrain_raw = X_Train_Augmented(idxTrain, :); 
            obj.YTrain = Y_Train_Augmented(idxTrain, :);

            XVal_raw   = X_Train_Augmented(idxVal, :);   
            obj.YVal   = Y_Train_Augmented(idxVal, :);

            XTest_raw  = X_Train_Augmented(idxTest, :);  
            obj.YTest  = Y_Train_Augmented(idxTest, :);

            % Normalizace Z-score - příprava
            mu = mean(XTrain_raw, 1); % průměr
            sig = std(XTrain_raw, 0, 1); % směrodatná odchylka
            sig(sig == 0) = 1; % ošetření před stejnými hodnotami

            % Normalizace Z-score (průměr 0, rozptyl 1)          
            obj.XTrain = (XTrain_raw - mu) ./ sig;
            obj.XVal   = (XVal_raw - mu) ./ sig;
            obj.XTest  = (XTest_raw - mu) ./ sig;
            obj.numFeatures = size(obj.XTrain, 2);
        end

        % Oprava řešení
        function PopDec = CalDec(obj, PopDec)
            PopDec = round(PopDec);
            PopDec = max(min(PopDec, repmat(obj.upper, size(PopDec,1), 1)), repmat(obj.lower, size(PopDec,1), 1));

            % Zajištění zužování MLP
            for i = 1:size(PopDec, 1)
                PopDec(i, 3) = min(PopDec(i, 3), PopDec(i, 2)); 
                PopDec(i, 4) = min(PopDec(i, 4), PopDec(i, 3)); 
            end
        end

        % Určení cílových/hodnotících hodnot pro fitness funkci
        function PopObj = CalObj(obj, PopDec)
            num_individuals = size(PopDec, 1);
            PopObj = zeros(num_individuals, 1);

            % Hyper parametry
            curr_batch = 32; 
            curr_lr = 0.001; 
            curr_l2 = 0.001;

            % Algoritmus hodnotící celou populaci
            for i = 1:num_individuals
               
                obj.evalCount = obj.evalCount + 1;
               
                num_layers = PopDec(i, 1);    % Určení konkrétní konfigurace sítě (vrstvy, neurony)
               
                arch = PopDec(i, 2 : 1 + num_layers);
               
                arch_str = strjoin(arrayfun(@num2str, arch, 'UniformOutput', false), '-'); % Převod pro výpis

                % Dynamická stavba sítě
                layers = [ featureInputLayer(obj.numFeatures, 'Normalization', 'none') ];
                
                for l = 1:length(arch)

                    layers = [layers; fullyConnectedLayer(arch(l)); reluLayer()];

                end

                layers = [layers; fullyConnectedLayer(4); regressionLayer()];

                options = trainingOptions('adam', ...
                    'MaxEpochs', 150, ...
                    'MiniBatchSize', curr_batch, ...
                    'InitialLearnRate', curr_lr, ...
                    'L2Regularization', curr_l2, ...
                    'ValidationData', {obj.XVal, obj.YVal}, ...
                    'ValidationPatience', 30, ...
                    'ValidationFrequency', 50, ...
                    'Shuffle', 'every-epoch', ...
                    'Plots', 'none', ...
                    'Verbose', false);

                [net, info] = trainNetwork(obj.XTrain, obj.YTrain, layers, options);

                % Extrakce hodnot validační chyby
                val_rmse = info.ValidationRMSE(~isnan(info.ValidationRMSE));

                % Absolutní rozdíl mezi posledními hodnotami validace a tréninkem
                gap = abs(val_rmse(end) - info.TrainingRMSE(end));

                % Predikce a evaluace - přesnost, kvalita
                YPred = predict(net, obj.XVal);

                % Chyba Polohy [mm] přes euklidovskou vzdálenost
                err_mm = median(sqrt((obj.YVal(:,1) - YPred(:,1)).^2 + (obj.YVal(:,2) - YPred(:,2)).^2) * 1000);

                % Chyba Rotace [°]
                Angle_True = atan2(obj.YVal(:,4), obj.YVal(:,3));
                Angle_Pred = atan2(YPred(:,4), YPred(:,3));
                err_deg = rad2deg(median(abs(wrapToPi(Angle_True - Angle_Pred))));

                %% Výpočet kombinovaného fitness score
                norm_pos = err_mm / 500;   % Ref: 500mm
                norm_rot = err_deg / 180;  % Ref: 180deg

                % Kombinované skóre (50% poloha, 50% rotace)
                combined_err = (0.5 * norm_pos + 0.5 * norm_rot) * 500;

                raw_score = combined_err + (gap * 500); 
                K = 100;
                score = raw_score / (raw_score + K);

                fprintf('[Eval %d] [%s] -> Pos: %.1f mm | Rot: %.1f deg | Gap: %.4f | Skore: %.4f\n', ...
                    obj.evalCount, arch_str, err_mm, err_deg, gap, score);
                PopObj(i, 1) = score;
            end
        end
    end
end