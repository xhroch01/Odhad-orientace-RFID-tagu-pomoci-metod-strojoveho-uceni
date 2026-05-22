%% Start hyperparameter tuning - hledání lepších hyperparametrů prvotní architektury
% Startovací skript pro MLP_Hyper_parameter_Tuning.m
% spustit ve složce ...\PlatEMO\PlatEMO-master\PlatEMO-master\PlatEMO
% doplnit do složky .mat s augmentovaným datasetem

clear; 
clc;

% Velikost populace a počet evaluací
N_pop = 50;
max_evals = 1500; 

[Dec, Obj, Con] = platemo('algorithm', @DE, 'problem', @MLP_Hyper_parameter_Tuning, 'N', N_pop, 'maxFE', max_evals);

% Analýza a zobrazení výsledků
[sorted_scores, sorted_indices] = sort(Obj);
num_to_show = min(20, length(Obj));

fprintf('\n Nejlepších 20 kombinací hyperparametrů \n');
fprintf('Pořadí | Skóre  | Batch | LearnRate | L2 Reg    | Aktivace\n');
fprintf('----------------------------------------------------------\n');

act_list = {'ReLU', 'Leaky', 'Tanh'};

for i = 1:num_to_show

    idx = sorted_indices(i);

    p = Dec(idx, :);
    
    batch = round(p(1));

    lr = 10^p(2);

    l2 = 10^p(3);

    act = act_list{round(p(4))};
    
    fprintf('%-6d | %-6.4f | %-5d | %-9.5f | %-9.5f | %s\n', i, sorted_scores(i), batch, lr, l2, act);
end

save('MLP_Hyper_parameter_Tuning_Results.mat', 'Dec', 'Obj');