%% Skript pro nalezení nejlepších hyperparametrů k prvotní architektuře MLP sítě
% Skript je volán ze startovacího skriptu Start_Hyper_parameter_Tuning.m.m
% spustit ve složce ...\PlatEMO\PlatEMO-master\PlatEMO-master\PlatEMO

classdef MLP_Hyper_parameter_Tuning < PROBLEM
    
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
            obj.D = 4; % [BatchSize, Log_LR, Log_L2, Aktivace]
            
            % 1=real (spojité pro LR a L2), 2=integer (pro Batch a Aktivaci)
            obj.encoding = [2, 1, 1, 2]; 
            
            obj.lower = [16, -4.0, -5.0, 1]; 
            obj.upper = [128, -2.0, -1.0, 3]; % Aktivace: 1=ReLU, 2=Leaky, 3=Tanh
            
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

        % Určení cílových/hodnotících hodnot pro fitness funkci       
        function PopObj = CalObj(obj, PopDec)
            num_individuals = size(PopDec, 1);
            PopObj = zeros(num_individuals, 1);
            
            % Algoritmus hodnotící celou populaci            
            for i = 1:num_individuals
                obj.evalCount = obj.evalCount + 1;
                
                % Dekódování hyperparametrů
                curr_batch = round(PopDec(i, 1));
                curr_lr = 10^PopDec(i, 2); % Převod z logaritmické míry zpět (rovnoměrnější prohledání)
                curr_l2 = 10^PopDec(i, 3);
                act_idx = round(PopDec(i, 4));
                
                % Volba aktivační funkce
                switch act_idx
                    case 1, act_name = 'ReLU'; 
                        act_layer = reluLayer();

                    case 2, act_name = 'Leaky'; 
                        act_layer = leakyReluLayer();

                    case 3, act_name = 'Tanh'; 
                        act_layer = tanhLayer();
                end
                
                fprintf('[Eval %d] Batch: %d | LR: %.5f | L2: %.5f | Act: %s => ', ...
                    obj.evalCount, curr_batch, curr_lr, curr_l2, act_name);
                
                % Architektura MLP
                  layers = [ 
                        featureInputLayer(obj.numFeatures, 'Normalization', 'none')

                            fullyConnectedLayer(254)
                            act_layer

                            fullyConnectedLayer(4)
                            regressionLayer() 
                  ];
                
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
                
                % Výpočet fitness score - 50:50 Poloha:Rotace
                norm_pos = err_mm / 500;   
                norm_rot = err_deg / 180; 
                combined_err = (0.5 * norm_pos + 0.5 * norm_rot) * 500;
                
                raw_score = combined_err + (gap * 500); 
                K = 100;
                score = raw_score / (raw_score + K);
                
                fprintf('Pos: %.1f mm | Rot: %.1f deg | Skore: %.4f\n', err_mm, err_deg, score);
                PopObj(i, 1) = score;
            end
        end
    end
end
