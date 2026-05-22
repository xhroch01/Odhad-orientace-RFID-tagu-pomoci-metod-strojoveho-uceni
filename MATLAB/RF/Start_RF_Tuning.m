clear; 
clc;

% Velikost populace a počet evaluací
N_pop = 50;
max_evals = 1500; 

fprintf('Start DE optimalizace pro Random Forest (N=%d, maxFE=%d) \n', N_pop, max_evals);
[Dec, Obj, Con] = platemo('algorithm', @DE, 'problem', @RF_Hyper_parameter_Tuning, 'N', N_pop, 'maxFE', max_evals);

% Analýza a zobrazení výsledků
[sorted_scores, sorted_indices] = sort(Obj);
num_to_show = min(20, length(Obj));

fprintf('\n Nejlepších 20 kombinací hyperparametrů pro Random Forest (Sada 3) \n');
fprintf('Pořadí | Skóre  | NumTrees | MinLeafSize | mtry (Vars) | MaxSplits\n');
fprintf('------------------------------------------------------------------\n');

for i = 1:num_to_show
    idx = sorted_indices(i);
    p = Dec(idx, :);
    
    trees  = round(p(1));
    leaf   = round(p(2));
    mtry   = round(p(3));
    splits = round(p(4));
    
    fprintf('%-6d | %-6.4f | %-8d | %-11d | %-11d | %-9d\n', i, sorted_scores(i), trees, leaf, mtry, splits);
end

% Uložení výsledků do .mat souboru
save('RF_Hyper_parameter_Tuning_Results.mat', 'Dec', 'Obj');
