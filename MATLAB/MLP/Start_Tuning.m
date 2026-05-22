%% Start tuning - hledání lepší architektury
% Startovací skript pro MLP_Tuning.m
% spustit ve složce ...\PlatEMO\PlatEMO-master\PlatEMO-master\PlatEMO +
% doplnit do složky .mat s augmentovaným datasetem


clear; 
clc;

% Velikost populace
N_pop = 50;
max_evals = 2000;

% Volání PlatEMO
[Dec, Obj, Con] = platemo('algorithm', @DE, 'problem', @MLP_Tuning, 'N', N_pop, 'maxFE', max_evals);

% Dec = navržené počty vrstev a neuronů
% Obj = obsahuje fitness skóre

% Analýza a zobrazení výsledků
[sorted_scores, sorted_indices] = sort(Obj);
num_to_show = min(20, length(Obj));

fprintf('\n Výpis nejlepších 20 architektur \n');
fprintf('Pořadí | Skóre  | Vrstvy | N1  | N2  | N3 \n');
fprintf('----------------------------------------------- \n');

% Analýza výpisu výsledků
for i = 1:num_to_show

    idx = sorted_indices(i);
    p = Dec(idx, :);
    L = p(1); 

    n1 = p(2); 
    n2 = p(3); 
    n3 = p(4);

    if L == 1, n2 = 0; 
        n3 = 0; 
    elseif L == 2, n3 = 0; 
    end

    fprintf('%-6d | %-6.4f | %-6d | %-3d | %-3d | %-3d\n', i, sorted_scores(i), L, n1, n2, n3);
end

save('Results_PlatEMO_MLP.mat', 'Dec', 'Obj'); %zmenit název pro druhý běh architektury, aby se nepřepsal
