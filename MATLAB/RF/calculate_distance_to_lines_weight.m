% Chybova funkce pro určení vypočítané polohy s podporou vah
% Výpočet celkové vzdálenosti daného bodu 'point_YX' od všech čar ze struktury 'readers'.

function total_distance = calculate_distance_to_lines_weight(point_YX, readers, weights)

    % Pokud váhy nejsou zadány, všechny čtečky mají plnou váhu (1.0)
    if nargin < 3
        weights = ones(1, length(readers));
    end

    total_distance = 0; % Vychozi chyba
    yp = point_YX(1);   
    xp = point_YX(2);   

    for i = 1:length(readers)
        % Počátek čáry = střed čtečky
        y0 = readers(i).Y(1);
        x0 = readers(i).X(1);
        
        % Směr čáry: azimut od osy Y
        az_rad = deg2rad(readers(i).AoA_azimuth_deg);

        % Jednotkový směrový vektor v souřadném systému (Y vodorovně, X svisle):
        uY = cos(az_rad);  
        uX = sin(az_rad);  

        % Normálový vektor na přímku (kolmý k u) - vychází z obecné rovnice
        % přímky
        A = -uX;
        B =  uY;
        C =  uX*y0 - uY*x0; 

        % Vypocet kolme vzdalenosti - vzdálenost bodu yp, xp od přímky
        numerator   = abs(A*yp + B*xp + C);
        denominator = hypot(A, B);   

        if denominator < 1e-6
            distance = numerator;
        else
            distance = numerator / denominator;
        end

        % Least Squares – sčítání kvadrátů vzdáleností (kvůli velkým
        % odchylkam)
        % Aplikace váhy: Least Squares * Váha dané čtečky
        total_distance = total_distance + weights(i) * (distance^2);
    end
end