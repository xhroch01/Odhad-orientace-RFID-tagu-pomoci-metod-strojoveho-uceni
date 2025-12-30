% Chybova funkce pro určení vypočítané polohy tagu
% Výpočet celkové vzdálenosti daného bodu 'point_YX' od všech čar ze struktury 'readers'.
function total_distance = calculate_distance_to_lines(point_YX, readers)

    total_distance = 0; % Vychozi chyba
    yp = point_YX(1);   % testovací Y souřadnice bodu
    xp = point_YX(2);   % testovací X souřadnice bodu

    % Projde všechny čáry (čtečky)
    for i = 1:length(readers)
        % Počátek čáry = střed čtečky
        y0 = readers(i).Y(1);
        x0 = readers(i).X(1);

        % Směr čáry: azimut od osy Y
        az_rad = deg2rad(readers(i).AoA_azimuth_deg);

        % Jednotkový směrový vektor v souřadném systému (Y vodorovně, X svisle):
        uY = cos(az_rad);  % složka ve směru osy Y
        uX = sin(az_rad);  % složka ve směru osy X

        % Normálový vektor na přímku (kolmý k u) - vychází z obecné rovnice
        % přímky
        A = -uX;
        B =  uY;
        C =  uX*y0 - uY*x0; % aby přímka procházela y0, x0 - středem čtečky

        % Vypocet kolme vzdalenosti - vzdálenost bodu yp, xp od přímky
        numerator   = abs(A*yp + B*xp + C);
        denominator = hypot(A, B);   % jiný zápis sqrt(A^2 + B^2), velikost vektoru přímky

        if denominator < 1e-6
            distance = numerator;
        else
            distance = numerator / denominator;
        end

        % Least Squares – sčítání kvadrátů vzdáleností (kvůli velkým
        % odchylkam)
        total_distance = total_distance + distance^2;
    end
end
