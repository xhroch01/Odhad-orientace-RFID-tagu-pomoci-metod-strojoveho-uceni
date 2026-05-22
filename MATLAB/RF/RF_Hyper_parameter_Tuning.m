%% OOB varianta
classdef RF_Hyper_parameter_Tuning < PROBLEM
    
    % Vlastnosti třídy - "vnitrni pamet"
    properties(Access = private)
        XTrain; 
        YTrain; 
        XTest; % použito až ve finálním modelu
        YTest; % použito až ve finálním modelu
        numFeatures;

        % Počítadlo výpisu
        evalCount = 0; 
    end

    methods
        function Setting(obj)
            % Rozhodovací prostor a meze pro Random Forest
            obj.M = 1; 
            obj.D = 4; % [NumTrees, MinLeafSize, NumVariablesToSample, MaxNumSplits]
            
            % Všechny hyperparametry pro RF jsou celá čísla (integer)
            obj.encoding = [2, 2, 2, 2]; 

            % Nastaveni mezí
            obj.lower = [10,  10,  1,  10]; 
            obj.upper = [300, 100, 12, 200];
            
            % Načtení dat (Sada 3: AoA, Rezidua, Amplitudy)
            data = readtable('Results_RF_data_lambda3.csv');

            X_all = data{:, {'AoA_R1', 'AoA_R2', 'AoA_R3', 'AoA_R4', ...
                             'Res_R1_mm', 'Res_R2_mm', 'Res_R3_mm', 'Res_R4_mm', ...
                             'Amp_R1', 'Amp_R2', 'Amp_R3', 'Amp_R4'}};

            Y_all = categorical(data.Target_Outlier);
            
            num_orig = size(X_all, 1); 
            rng(42, 'twister');

            % Zamíchání hodnot v datasetu        
            idx_base = randperm(num_orig);
            
            % Rozdělení dat na trénink+OOB (85%) a test (15%)          
            numTrainOOB = floor(0.85 * num_orig);
            
            idxTrainOOB = idx_base(1:numTrainOOB);
            idxTest     = idx_base(numTrainOOB+1 : end);
            
            % Přiřazení dat 
            obj.XTrain = X_all(idxTrainOOB, :); 
            obj.YTrain = Y_all(idxTrainOOB, :);
            obj.XTest  = X_all(idxTest, :);  
            obj.YTest  = Y_all(idxTest, :);
            
            obj.numFeatures = size(obj.XTrain, 2);
        end

        % Oprava řešení
        function PopDec = CalDec(obj, PopDec)
            PopDec = round(PopDec);
            PopDec = max(min(PopDec, repmat(obj.upper, size(PopDec,1), 1)), repmat(obj.lower, size(PopDec,1), 1));
        end

        % Určení cílových/hodnotících hodnot pro fitness funkci       
        function PopObj = CalObj(obj, PopDec)
            num_individuals = size(PopDec, 1);
            PopObj = zeros(num_individuals, 1);
            
            % Hodnocení celé populace
            for i = 1:num_individuals
                obj.evalCount = obj.evalCount + 1;
                
                % Dekódování hyperparametrů z DE
                curr_trees = round(PopDec(i, 1));
                curr_leaf  = round(PopDec(i, 2));
                curr_mtry  = round(PopDec(i, 3));
                curr_split = round(PopDec(i, 4));
                
                fprintf('[Eval %d] Trees: %3d | MinLeaf: %2d | mtry: %2d | MaxSplit: %3d => ', ...
                    obj.evalCount, curr_trees, curr_leaf, curr_mtry, curr_split);
                
                % Šablona pro strom uvnitř lesa
                t = templateTree('MinLeafSize', curr_leaf, ...
                                 'NumVariablesToSample', curr_mtry, ...
                                 'MaxNumSplits', curr_split);
                
                % Trénink Random Forest (při metodě Bag se automaticky zapíná OOB vzorkování)
                net = fitcensemble(obj.XTrain, obj.YTrain, ...
                                   'Method', 'Bag', ...
                                   'NumLearningCycles', curr_trees, ...
                                   'Learners', t);
                
                % Výpočet Out-of-Bag (OOB) chybovosti (rozsah 0-1)
                err_oob = oobLoss(net);
                
                % Penalizace za složitost (normalizovaný počet stromů + velikost listu)
                complexity_penalty = 0.001 * (curr_trees / obj.upper(1));
                leaf_penalty = 0.005 * exp(-curr_leaf / 10); % exponenciálně trestá malé listy
                
                % Výsledné fitness
                score = err_oob + complexity_penalty + leaf_penalty;

                fprintf('OOB Err: %.4f | Pen: %.6f | Skóre: %.4f\n', err_oob, complexity_penalty, score);
                PopObj(i, 1) = score;
               
            end
        end
    end
end