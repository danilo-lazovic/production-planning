clear; clc; close all;

%konfiguracija
config.backlogPenalty = 100;      % beklog
config.excessInventoryCost = 5;   % nepotrebne zalihe
config.safetyStockCost = 0.1;     
config.maxInventory = 500;
config.allowBacklog = true;       
config.useInteger = true;
config.planAheadDays = 7;         % Planiraj 7 dana unapred
config.minSafetyStock = 20;       % Minimalne sigurnosne zalihe
config.productionLeadTime = 2;    % Proizvodnja kreće 2 dana pre tražnje (optimizovano)
config.earlyProductionDays = 3;   % Koliko dana unapred možemo da proizvedemo

%% ============================
%% UČITAVANJE PODATAKA IZ SHEET1
%% ============================
filename = 'projekat.xlsx';
sheet = 'Sheet1';
raw = readcell(filename, 'Sheet', sheet);

% Konvertuj missing vrednosti 
for i = 1:size(raw,1)
    for j = 1:size(raw,2)
        if iscell(raw(i,j)) && numel(raw{i,j}) > 1
            continue;
        end
        try
            if ismissing(raw{i,j})
                raw{i,j} = '';
            elseif isnumeric(raw{i,j}) && isnan(raw{i,j})
                raw{i,j} = '';
            end
        catch
            raw{i,j} = '';
        end
    end
end

%% ============================
%% PRONALAŽENJE KLJUČNIH REDOVA
%% ============================
% Traženje početka PN podataka
startRow = NaN;
for r = 1:size(raw,1)
    if iscell(raw(r,1)) && ~isempty(raw{r,1}) && ischar(raw{r,1}) && startsWith(raw{r,1}, 'PN-')
        startRow = r;
        break;
    end
end

if isnan(startRow)
    error('Nije pronađen početak PN podataka u Sheet1!');
end

% Pronalaženje reda sa danima (Pon, Uto, Sre...)
dayRow = [];
dayNames = {'Pon', 'Uto', 'Sre', 'Cet', 'Pet', 'Sub', 'Ned'};
for r = 1:min(20, size(raw,1))
    if r <= size(raw,1) && iscell(raw(r,3)) && ~isempty(raw{r,3})
        if ischar(raw{r,3}) && any(strcmp(raw{r,3}, dayNames))
            dayRow = r;
            break;
        end
    end
end

% Ako nije pronađen red sa danima, traži ispod CW
if isempty(dayRow)
    for r = 1:min(20, size(raw,1))
        if r <= size(raw,1) && iscell(raw(r,3)) && ~isempty(raw{r,3})
            if ischar(raw{r,3}) && startsWith(raw{r,3}, 'CW')
                dayRow = r + 1; % red ispod CW sadrži dane
                break;
            end
        end
    end
end

% Pronalaženje reda sa kapacitetom
capacityRow = [];
for r = 1:min(10, size(raw,1))
    if r <= size(raw,1) && iscell(raw(r,3)) && ~isempty(raw{r,3}) && ischar(raw{r,3})
        if contains(lower(raw{r,3}), 'kapacitet')
            capacityRow = r;
            break;
        end
    end
end

%% ============================
%% ODREDIVANJE BROJA DANA
%% ============================
numDays = 0;
if ~isempty(dayRow)
    for c = 3:size(raw,2)
        if iscell(raw(dayRow,c)) && ~isempty(raw{dayRow,c}) && ischar(raw{dayRow,c})
            if any(strcmp(raw{dayRow,c}, dayNames))
                numDays = numDays + 1;
            else
                break;
            end
        else
            break;
        end
    end
end

% Ako nije pronađeno, proveri maksimalni broj kolona
if numDays == 0
    fprintf('⚠️ Red sa danima nije pronađen. Pokušavam automatsko određivanje...\n');
    
    % Proveri planed order redove
    for p = 1:5
        testRow = startRow + (p-1)*4 + 2;
        if testRow <= size(raw,1)
            lastNumCol = 2;
            for c = 3:size(raw,2)
                if iscell(raw(testRow,c)) && ~isempty(raw{testRow,c})
                    if isnumeric(raw{testRow,c})
                        lastNumCol = c;
                    elseif ischar(raw{testRow,c})
                        numVal = str2double(raw{testRow,c});
                        if ~isnan(numVal)
                            lastNumCol = c;
                        end
                    end
                end
            end
            numDays = max(numDays, lastNumCol - 2);
        end
    end
end

if numDays == 0
    numDays = 50;
    fprintf('⚠️ Broj dana automatski određen: %d\n', numDays);
else
    fprintf('✓ Broj dana u planu: %d\n', numDays);
end

%% ============================
%% MAPIRANJE DANA U NEDELJE
%% ============================
daysPerWeek = 7;
numWeeks = ceil(numDays / daysPerWeek);

% Kreiranje mape dan -> nedelja
dayToWeek = zeros(1, numDays);
weekStarts = 1:daysPerWeek:numDays;

for w = 1:numWeeks
    startDay = weekStarts(w);
    endDay = min(startDay + daysPerWeek - 1, numDays);
    dayToWeek(startDay:endDay) = w;
end

%% ============================
%% BROJ PN-OVA
%% ============================
pnCount = 0;
for r = startRow:4:size(raw,1)
    if r <= size(raw,1) && iscell(raw(r,1)) && ~isempty(raw{r,1}) && ischar(raw{r,1}) && startsWith(raw{r,1}, 'PN-')
        pnCount = pnCount + 1;
    else
        break;
    end
end
fprintf('✓ Broj PN-ova: %d\n', pnCount);

%% ============================
%% UČITAVANJE DNEVNOG KAPACITETA
%% ============================
capacity_daily = zeros(1, numDays);
defaultCapacity = 320;

if ~isempty(capacityRow)
    capValueRow = capacityRow + 1;
    
    for d = 1:numDays
        col = d + 2;
        if col <= size(raw,2) && iscell(raw(capValueRow,col)) && ~isempty(raw{capValueRow,col})
            val = raw{capValueRow, col};
            
            if isnumeric(val)
                capacity_daily(d) = val;
            elseif ischar(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    capacity_daily(d) = numVal;
                else
                    capacity_daily(d) = defaultCapacity;
                end
            else
                capacity_daily(d) = defaultCapacity;
            end
        else
            capacity_daily(d) = defaultCapacity;
        end
    end
    fprintf('✓ Dnevni kapacitet učitavan iz Excel-a\n');
else
    capacity_daily(:) = defaultCapacity;
    fprintf('⚠️ Kapacitet nije pronađen. Koristim podrazumevani: %d\n', defaultCapacity);
end

%% ============================
%% UČITAVANJE DNEVNE TRAŽNJE
%% ============================
demand_daily = zeros(pnCount, numDays);

for p = 1:pnCount
    orderRow = startRow + (p-1)*4 + 2;
    
    if orderRow > size(raw,1)
        continue;
    end
    
    for d = 1:numDays
        col = d + 2;
        if col <= size(raw,2) && iscell(raw(orderRow,col))
            val = raw{orderRow, col};
            
            if isnumeric(val)
                demand_daily(p, d) = val;
            elseif ischar(val)
                numVal = str2double(val);
                if ~isnan(numVal)
                    demand_daily(p, d) = numVal;
                else
                    demand_daily(p, d) = 0;
                end
            else
                demand_daily(p, d) = 0;
            end
        else
            demand_daily(p, d) = 0;
        end
    end
end

%% ============================
%% ANALIZA PODATAKA
%% ============================
fprintf('\n=== DNEVNA ANALIZA PODATAKA ===\n');
total_demand_per_day = sum(demand_daily, 1);

% Prikaz prvih 14 dana
fprintf('\nPrvih 14 dana (Tražnja / Kapacitet):\n');
for d = 1:min(14, numDays)
    weekNum = dayToWeek(d);
    dayName = dayNames{mod(d-1, 7) + 1};
    
    fprintf('Dan %02d (%s, CW%02d): %4d / %4d', d, dayName, weekNum, ...
        total_demand_per_day(d), capacity_daily(d));
    
    if total_demand_per_day(d) > capacity_daily(d)
        fprintf(' ⚠️ +%d', total_demand_per_day(d) - capacity_daily(d));
    end
    fprintf('\n');
end

%% ============================
%% POBOLJŠANA OPTIMIZACIJA SA 3 NIVOA ZALIHA
%% ============================
fprintf('\n=== OPTIMIZACIJA SA 3 NIVOA ZALIHA ===\n');

% Optimizacija koja kažnjava backlog JAKO, kažnjava nepotrebne zalihe UMERENO,
% i nagrađuje (ili barem ne kažnjava) nužne zalihe

[release_daily, inventory_total, backlog_daily, exitflag, fval] = ...
    solveThreeLevelInventory(demand_daily, capacity_daily, pnCount, numDays, config);

%% ============================
%% AUTOMATSKO POMERANJE PROIZVODNJE UNAPRIJED
%% ============================
fprintf('\n=== AUTOMATSKO POMERANJE PROIZVODNJE ===\n');

% 1. Pronađi dane sa backlog-om
backlog_days = find(sum(backlog_daily, 1) > 0);

if ~isempty(backlog_days)
    fprintf('Pronađeni backlog u danima: %s\n', mat2str(backlog_days));
    
    % 2. Pokušaj da rešiš backlog pomeranjem proizvodnje unapred
    [release_adjusted, backlog_resolved] = resolveBacklogByEarlyProduction(...
        release_daily, backlog_daily, demand_daily, capacity_daily, ...
        pnCount, numDays, config);
    
    if backlog_resolved
        fprintf('✅ Backlog rešen pomeranjem proizvodnje unapred!\n');
        release_daily = release_adjusted;
    else
        fprintf('⚠️ Nije moguće potpuno rešiti backlog pomeranjem proizvodnje\n');
    end
else
    fprintf('✅ Nema backlog-a u planu\n');
end

%% ============================
%% PLANIRANJE PROIZVODNJE UNAPRIJED ZA BUDUĆU TRAŽNJU
%% ============================
fprintf('\n=== PLANIRANJE PROIZVODNJE UNAPRIJED ===\n');

% Za svaki dan sa tražnjom, planiraj proizvodnju unapred
planned_release_advanced = release_daily;

for d = 1:numDays
    for p = 1:pnCount
        if demand_daily(p, d) > 0
            % Koliko dana unapred možemo da planiramo proizvodnju
            earliest_prod_day = max(1, d - config.earlyProductionDays);
            
            % Pokušaj da rasporediš proizvodnju unapred
            remaining_demand = demand_daily(p, d);
            
            for prod_day = earliest_prod_day:d-1
                if remaining_demand <= 0
                    break;
                end
                
                % Proveri da li postoji slobodan kapacitet u ranijem danu
                current_cap_used = sum(planned_release_advanced(:, prod_day));
                available_capacity = capacity_daily(prod_day) - current_cap_used;
                
                if available_capacity > 0
                    % Pomeri deo proizvodnje unapred
                    move_amount = min(remaining_demand, available_capacity);
                    planned_release_advanced(p, prod_day) = planned_release_advanced(p, prod_day) + move_amount;
                    planned_release_advanced(p, d) = planned_release_advanced(p, d) - move_amount;
                    remaining_demand = remaining_demand - move_amount;
                    
                    if move_amount > 0
                        fprintf('  PN-%d: Proizvodnja %d jedinica pomeren iz D%02d u D%02d\n', ...
                            p, move_amount, d, prod_day);
                    end
                end
            end
        end
    end
end

%% ============================
%% PROVERA KAPACITETA I IZBEGAVANJE BACKLOG-A
%% ============================
fprintf('\n=== FINALNA PROVERA KAPACITETA ===\n');

% Ažuriraj zalihe sa poboljšanim planom
[inventory_final, backlog_final] = calculateInventory(planned_release_advanced, demand_daily, pnCount, numDays);

% Proveri iskorišćenje kapaciteta
capacity_utilization = zeros(1, numDays);
for d = 1:numDays
    capacity_utilization(d) = sum(planned_release_advanced(:, d)) / capacity_daily(d) * 100;
    
    if sum(planned_release_advanced(:, d)) > capacity_daily(d)
        fprintf('⚠️ Dan %d (%s): PREKORAČENJE KAPACITETA! %d > %d\n', ...
            d, dayNames{mod(d-1, 7) + 1}, ...
            sum(planned_release_advanced(:, d)), capacity_daily(d));
    end
end

% Prikaz rezultata
showImprovedResults(planned_release_advanced, inventory_final, backlog_final, ...
    demand_daily, capacity_daily, dayToWeek, dayNames, numDays);

%% ============================
%% UPIS U EXCEL
%% ============================
outputFilename = saveImprovedToExcel(raw, startRow, pnCount, numDays, ...
    planned_release_advanced, inventory_final, backlog_final, capacity_daily, ...
    dayToWeek, dayNames, demand_daily); % ← DODAO SAM demand_daily OVDE!

fprintf('\n✅ Izveštaj sačuvan: %s\n', outputFilename);

%% ============================
%% GRAFIKONI
%% ============================
makeImprovedPlots(pnCount, numDays, demand_daily, planned_release_advanced, ...
    inventory_final, backlog_final, capacity_daily, dayToWeek, dayNames);

fprintf('\n=== ZAVRŠENO ===\n');

%% ========================================================================
%% POMOĆNE FUNKCIJE
%% ========================================================================

function [release, inventory_total, backlog, exitflag, fval] = ...
    solveThreeLevelInventory(demand, capacity, pnCount, numDays, config)
    
    fprintf('Koristim model sa 3 nivoa zaliha...\n');
    
    % Varijable za svaki PN i dan:
    % 1- numDays: proizvodnja (release)
    % numDays+1 - 2*numDays: nužne zalihe (safety stock)
    % 2*numDays+1 - 3*numDays: višak zaliha (excess inventory)
    % 3*numDays+1 - 4*numDays: backlog
    
    vars_per_pn = 4 * numDays;
    N = pnCount * vars_per_pn;
    
    % CILJNA FUNKCIJA sa različitim cenama za različite vrste zaliha
    f = zeros(N, 1);
    
    for p = 1:pnCount
        % 1. Nužne zalihe - veoma niska cena
        for d = 1:numDays
            idx_safety = numDays + (p-1)*vars_per_pn + d;
            f(idx_safety) = config.safetyStockCost;
        end
        
        % 2. Višak zaliha - umerena cena
        for d = 1:numDays
            idx_excess = 2*numDays + (p-1)*vars_per_pn + d;
            f(idx_excess) = config.excessInventoryCost;
        end
        
        % 3. Backlog - VISOKA CENA (najgore)
        for d = 1:numDays
            idx_backlog = 3*numDays + (p-1)*vars_per_pn + d;
            f(idx_backlog) = config.backlogPenalty;
        end
    end
    
    % OGRANIČENJA
    Aeq = []; beq = [];
    
    for p = 1:pnCount
        for d = 1:numDays
            Aeq_row = zeros(1, N);
            
            % Indeksi za ovaj PN i dan
            idx_x = (p-1)*vars_per_pn + d;  % proizvodnja
            idx_safety = numDays + (p-1)*vars_per_pn + d;  % nužne zalihe
            idx_excess = 2*numDays + (p-1)*vars_per_pn + d;  % višak
            idx_backlog = 3*numDays + (p-1)*vars_per_pn + d;  % backlog
            
            % Jednačina zaliha: I_t = I_{t-1} + X_t - D_t
            Aeq_row(idx_safety) = 1;
            Aeq_row(idx_excess) = 1;
            Aeq_row(idx_backlog) = -1;  % backlog je negativne zalihe
            Aeq_row(idx_x) = -1;
            
            if d > 1
                idx_safety_prev = numDays + (p-1)*vars_per_pn + (d-1);
                idx_excess_prev = 2*numDays + (p-1)*vars_per_pn + (d-1);
                idx_backlog_prev = 3*numDays + (p-1)*vars_per_pn + (d-1);
                
                Aeq_row(idx_safety_prev) = -1;
                Aeq_row(idx_excess_prev) = -1;
                Aeq_row(idx_backlog_prev) = 1;
            end
            
            Aeq = [Aeq; Aeq_row];
            beq = [beq; -demand(p, d)];
        end
    end
    
    % OGRANIČENJE KAPACITETA
    Aineq = []; bineq = [];
    for d = 1:numDays
        Aineq_row = zeros(1, N);
        for p = 1:pnCount
            idx_x = (p-1)*vars_per_pn + d;
            Aineq_row(idx_x) = 1;
        end
        Aineq = [Aineq; Aineq_row];
        bineq = [bineq; capacity(d)];
    end
    
    % DONJE I GORNJE GRANICE
    lb = zeros(N, 1);
    ub = inf(N, 1);
    
    % Nužne zalihe - ograničene na maxInventory
    for p = 1:pnCount
        for d = 1:numDays
            idx_safety = numDays + (p-1)*vars_per_pn + d;
            ub(idx_safety) = config.maxInventory;
        end
    end
    
    % Višak zaliha - ograničen na maxInventory
    for p = 1:pnCount
        for d = 1:numDays
            idx_excess = 2*numDays + (p-1)*vars_per_pn + d;
            ub(idx_excess) = config.maxInventory;
        end
    end
    
    % Backlog - ograničen na maxInventory
    for p = 1:pnCount
        for d = 1:numDays
            idx_backlog = 3*numDays + (p-1)*vars_per_pn + d;
            ub(idx_backlog) = config.maxInventory;
        end
    end
    
    % MINIMALNE NUŽNE ZALIHE (safety stock)
    for p = 1:pnCount
        for d = 1:numDays
            idx_safety = numDays + (p-1)*vars_per_pn + d;
            lb(idx_safety) = config.minSafetyStock;
        end
    end
    
    % REŠAVANJE
    if config.useInteger
        intcon = 1:N;
        options = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 300);
        [xsol, fval, exitflag] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub, options);
    else
        options = optimoptions('linprog', 'Display', 'off');
        [xsol, fval, exitflag] = linprog(f, Aineq, bineq, Aeq, beq, lb, ub, options);
    end
    
    % EKSTRAKCIJA REZULTATA
    if exitflag > 0
        release = zeros(pnCount, numDays);
        safety_stock = zeros(pnCount, numDays);
        excess_inv = zeros(pnCount, numDays);
        backlog = zeros(pnCount, numDays);
        
        for p = 1:pnCount
            for d = 1:numDays
                idx_x = (p-1)*vars_per_pn + d;
                idx_safety = numDays + (p-1)*vars_per_pn + d;
                idx_excess = 2*numDays + (p-1)*vars_per_pn + d;
                idx_backlog = 3*numDays + (p-1)*vars_per_pn + d;
                
                if config.useInteger
                    release(p,d) = round(xsol(idx_x));
                    safety_stock(p,d) = round(xsol(idx_safety));
                    excess_inv(p,d) = round(xsol(idx_excess));
                    backlog(p,d) = round(xsol(idx_backlog));
                else
                    release(p,d) = xsol(idx_x);
                    safety_stock(p,d) = xsol(idx_safety);
                    excess_inv(p,d) = xsol(idx_excess);
                    backlog(p,d) = xsol(idx_backlog);
                end
            end
        end
        
        inventory_total = safety_stock + excess_inv - backlog;
        
        fprintf('✅ Optimizacija uspešna!\n');
        fprintf('   - Ukupne zalihe: %d\n', sum(inventory_total(:)));
        fprintf('   - Ukupan backlog: %d\n', sum(backlog(:)));
        fprintf('   - Ukupan safety stock: %d\n', sum(safety_stock(:)));
        
    else
        release = []; inventory_total = []; backlog = [];
        fprintf('❌ Optimizacija nije uspela\n');
        fval = inf;
    end
end

function [release_adjusted, backlog_resolved] = resolveBacklogByEarlyProduction(...
    release, backlog, demand, capacity, pnCount, numDays, config)
    
    release_adjusted = release;
    backlog_remaining = backlog;
    backlog_resolved = false;
    
    % Za svaki PN sa backlog-om
    for p = 1:pnCount
        backlog_days = find(backlog(p, :) > 0);
        
        for d = backlog_days
            backlog_amount = backlog(p, d);
            
            if backlog_amount <= 0
                continue;
            end
            
            % Pokušaj da rešiš backlog pomeranjem proizvodnje iz prethodnih dana
            earliest_day = max(1, d - config.earlyProductionDays);
            
            for earlier_day = earliest_day:d-1
                if backlog_amount <= 0
                    break;
                end
                
                % Proveri da li postoji proizvodnja u ranijem danu
                current_prod = release_adjusted(p, earlier_day);
                
                if current_prod > 0
                    % Pokušaj da prebaciš deo proizvodnje u još raniji dan
                    for even_earlier = max(1, earlier_day-3):earlier_day-1
                        if backlog_amount <= 0
                            break;
                        end
                        
                        % Proveri kapacitet u ranijem danu
                        current_cap_used = sum(release_adjusted(:, even_earlier));
                        available_capacity = capacity(even_earlier) - current_cap_used;
                        
                        if available_capacity > 0
                            move_amount = min([backlog_amount, current_prod, available_capacity]);
                            
                            if move_amount > 0
                                % Pomeri proizvodnju unapred
                                release_adjusted(p, even_earlier) = release_adjusted(p, even_earlier) + move_amount;
                                release_adjusted(p, earlier_day) = release_adjusted(p, earlier_day) - move_amount;
                                
                                backlog_amount = backlog_amount - move_amount;
                                
                                fprintf('  PN-%d: Pomerio %d iz D%02d u D%02d za rešavanje backlog-a u D%02d\n', ...
                                    p, move_amount, earlier_day, even_earlier, d);
                            end
                        end
                    end
                end
            end
        end
    end
    
    % Proveri da li je backlog rešen
    [~, new_backlog] = calculateInventory(release_adjusted, demand, pnCount, numDays);
    total_backlog = sum(new_backlog(:));
    
    if total_backlog == 0
        backlog_resolved = true;
        fprintf('✅ SAV BACKLOG REŠEN!\n');
    else
        fprintf('⚠️ Preostali backlog: %d jedinica\n', total_backlog);
    end
end

function [inventory, backlog] = calculateInventory(release, demand, pnCount, numDays)
    inventory = zeros(pnCount, numDays);
    backlog = zeros(pnCount, numDays);
    
    for p = 1:pnCount
        for d = 1:numDays
            if d == 1
                net_inv = release(p, d) - demand(p, d);
            else
                net_inv = inventory(p, d-1) + release(p, d) - demand(p, d);
            end
            
            if net_inv >= 0
                inventory(p, d) = net_inv;
                backlog(p, d) = 0;
            else
                inventory(p, d) = 0;
                backlog(p, d) = -net_inv;
            end
        end
    end
end

function showImprovedResults(release, inventory, backlog, demand, capacity, dayToWeek, dayNames, numDays)
    used_cap = sum(release, 1);
    total_backlog = sum(backlog(:));
    total_inventory = sum(inventory(:));
    
    fprintf('\n=== POBOLJŠANI REZULTATI ===\n');
    fprintf('Ukupne zalihe: %d\n', total_inventory);
    fprintf('Ukupan backlog: %d\n', total_backlog);
    
    fprintf('\nIskorišćenje kapaciteta (prvih 10 dana):\n');
    
    for d = 1:min(10, numDays)
        weekNum = dayToWeek(d);
        dayName = dayNames{mod(d-1, 7) + 1};
        
        fprintf('Dan %02d (%s, CW%02d): %4d/%4d (%.0f%%)', d, dayName, weekNum, ...
            used_cap(d), capacity(d), 100*used_cap(d)/capacity(d));
        
        if used_cap(d) > capacity(d)
            fprintf(' ⚠️');
        end
        fprintf('\n');
    end
    
    % Nedeljni pregled
    fprintf('\nNedeljni pregled:\n');
    numWeeks = max(dayToWeek);
    
    for w = 1:numWeeks
        weekDays = find(dayToWeek == w);
        weekUsed = sum(used_cap(weekDays));
        weekCapacity = sum(capacity(weekDays));
        weekBacklog = sum(sum(backlog(:, weekDays)));
        
        fprintf('CW%02d: %4d/%4d (%.1f%%)', w, weekUsed, weekCapacity, ...
            100*weekUsed/weekCapacity);
        
        if weekBacklog > 0
            fprintf(' ⚠️ Backlog: %d', weekBacklog);
        end
        fprintf('\n');
    end
end

% IZMENJENA FUNKCIJA - dodaj demand_daily kao parametar
function filename = saveImprovedToExcel(raw, startRow, pnCount, numDays, ...
    release, inventory, backlog, capacity, dayToWeek, dayNames, demand_daily) % ← DODATO!
    
    newData = raw;
    
    % 1. Upis planned release sa planiranjem unapred
    for p = 1:pnCount
        releaseRow = startRow + (p-1)*4 + 1;
        if releaseRow <= size(newData,1)
            for d = 1:numDays
                col = d + 2;
                if col <= size(newData,2)
                    newData{releaseRow, col} = release(p, d);
                end
            end
        end
    end
    
    % 2. Upis cummulative
    for p = 1:pnCount
        cumRow = startRow + (p-1)*4 + 3;
        if cumRow <= size(newData,1)
            for d = 1:numDays
                col = d + 2;
                if col <= size(newData,2)
                    newData{cumRow, col} = inventory(p, d);
                end
            end
        end
    end
    
    % 3. Konvertuj ćelije
    newData = safeConvertCells(newData);
    
    % 4. Snimi glavni sheet
    timestamp = datestr(now, 'yyyy-mm-dd_HHMM');
    filename = sprintf('poboljsani_plan_%s.xlsx', timestamp);
    
    if exist(filename, 'file')
        delete(filename);
    end
    
    writecell(newData, filename, 'Sheet', 'Plan');
    
    % 5. Dodaj sheet sa analizom backlog-a
    addBacklogAnalysis(filename, pnCount, numDays, backlog, dayToWeek, dayNames);
    
    % 6. Dodaj sheet sa analizom proizvodnje unapred - prosleđujemo demand_daily
    addEarlyProductionAnalysis(filename, pnCount, numDays, release, demand_daily, dayToWeek, dayNames);
    
    % 7. Dodaj sheet sa DETALJNIM IZVEŠTAJEM ZA SVE DANE
    addDetailedReport(filename, pnCount, numDays, demand_daily, release, inventory, backlog, capacity, dayToWeek, dayNames);
    
    fprintf('\n✅ Poboljšani plan sačuvan: %s\n', filename);
end

function addBacklogAnalysis(filename, pnCount, numDays, backlog, dayToWeek, dayNames)
    backlogSheet = cell(pnCount + 5, numDays + 3);
    backlogSheet{1,1} = 'BACKLOG ANALIZA';
    backlogSheet{3,1} = 'PN';
    backlogSheet{3,2} = 'Nedelja';
    backlogSheet{3,3} = 'Dan u nedelji';
    
    for d = 1:numDays
        backlogSheet{3, d+3} = sprintf('D%02d', d);
    end
    
    total_backlog_per_pn = sum(backlog, 2);
    
    for p = 1:pnCount
        backlogSheet{p+3, 1} = sprintf('PN-%04d', p);
        backlogSheet{p+3, 2} = '';
        backlogSheet{p+3, 3} = '';
        
        for d = 1:numDays
            if backlog(p, d) > 0
                backlogSheet{p+3, d+3} = backlog(p, d);
            else
                backlogSheet{p+3, d+3} = 0;
            end
        end
    end
    
    % Dodaj sumu
    backlogSheet{pnCount+4, 1} = 'UKUPNO';
    backlogSheet{pnCount+4, 2} = '';
    backlogSheet{pnCount+4, 3} = '';
    
    for d = 1:numDays
        backlogSheet{pnCount+4, d+3} = sum(backlog(:, d));
    end
    
    writecell(backlogSheet, filename, 'Sheet', 'Backlog Analiza');
end

function addEarlyProductionAnalysis(filename, pnCount, numDays, release, demand, dayToWeek, dayNames)
    % PROŠIRENA ANALIZA SA DETALJNIM PRIKAZOM
    earlySheet = cell(pnCount + 10, 8);
    earlySheet{1,1} = 'ANALIZA PROIZVODNJE UNAPRIJED';
    earlySheet{3,1} = 'PN';
    earlySheet{3,2} = 'Ukupna tražnja';
    earlySheet{3,3} = 'Ukupna proizvodnja';
    earlySheet{3,4} = 'Proizvodnja 3+ dana pre tražnje';
    earlySheet{3,5} = 'Proizvodnja 2 dana pre tražnje';
    earlySheet{3,6} = 'Proizvodnja 1 dan pre tražnje';
    earlySheet{3,7} = 'Proizvodnja istog dana';
    earlySheet{3,8} = '% Proizvodnje unapred';
    
    for p = 1:pnCount
        earlySheet{p+3, 1} = sprintf('PN-%04d', p);
        earlySheet{p+3, 2} = sum(demand(p, :));
        earlySheet{p+3, 3} = sum(release(p, :));
        
        % Broj dana unapred
        early_3plus = 0;
        early_2 = 0;
        early_1 = 0;
        same_day = 0;
        
        for d = 1:numDays
            if release(p, d) > 0
                % Proveri da li postoji tražnja u narednih 3 dana
                found_demand = false;
                
                for future_day = d+1:min(d+3, numDays)
                    if demand(p, future_day) > 0
                        days_ahead = future_day - d;
                        if days_ahead >= 3
                            early_3plus = early_3plus + release(p, d);
                        elseif days_ahead == 2
                            early_2 = early_2 + release(p, d);
                        elseif days_ahead == 1
                            early_1 = early_1 + release(p, d);
                        end
                        found_demand = true;
                        break;
                    end
                end
                
                if ~found_demand
                    % Proveri da li ima tražnje istog dana
                    if demand(p, d) > 0
                        same_day = same_day + release(p, d);
                    end
                end
            end
        end
        
        earlySheet{p+3, 4} = early_3plus;
        earlySheet{p+3, 5} = early_2;
        earlySheet{p+3, 6} = early_1;
        earlySheet{p+3, 7} = same_day;
        
        total_early = early_3plus + early_2 + early_1;
        total_prod = sum(release(p, :));
        if total_prod > 0
            early_percentage = total_early / total_prod * 100;
            earlySheet{p+3, 8} = sprintf('%.1f%%', early_percentage);
        else
            earlySheet{p+3, 8} = '0%';
        end
    end
    
    % Dodaj sumarne podatke
    row = pnCount + 4;
    earlySheet{row, 1} = 'UKUPNO';
    earlySheet{row, 2} = sum(sum(demand));
    earlySheet{row, 3} = sum(sum(release));
    
    writecell(earlySheet, filename, 'Sheet', 'Proizvodnja Unapred');
end

% NOVA FUNKCIJA: DETALJAN IZVEŠTAJ ZA SVE DANE
function addDetailedReport(filename, pnCount, numDays, demand, release, inventory, backlog, capacity, dayToWeek, dayNames)
    % Kreiraj detaljan izveštaj sa svim danima
    detailedSheet = cell(numDays + 10, 8);
    
    detailedSheet{1,1} = 'DETALJAN DNEVNI IZVEŠTAJ';
    detailedSheet{3,1} = 'Dan';
    detailedSheet{3,2} = 'Nedelja';
    detailedSheet{3,3} = 'Tražnja (ukupno)';
    detailedSheet{3,4} = 'Proizvodnja (ukupno)';
    detailedSheet{3,5} = 'Iskorišćenost kapaciteta';
    detailedSheet{3,6} = 'Zalihe (ukupno)';
    detailedSheet{3,7} = 'Backlog (ukupno)';
    detailedSheet{3,8} = 'Status';
    
    for d = 1:numDays
        row = d + 3;
        
        % Dan i nedelja
        detailedSheet{row, 1} = sprintf('D%02d (%s)', d, dayNames{mod(d-1, 7) + 1});
        detailedSheet{row, 2} = sprintf('CW%02d', dayToWeek(d));
        
        % Tražnja
        total_demand = sum(demand(:, d));
        detailedSheet{row, 3} = total_demand;
        
        % Proizvodnja
        total_release = sum(release(:, d));
        detailedSheet{row, 4} = total_release;
        
        % Iskorišćenost kapaciteta
        if capacity(d) > 0
            utilization = total_release / capacity(d) * 100;
            detailedSheet{row, 5} = sprintf('%.1f%%', utilization);
        else
            detailedSheet{row, 5} = '0%';
        end
        
        % Zalihe
        total_inventory = sum(inventory(:, d));
        detailedSheet{row, 6} = total_inventory;
        
        % Backlog
        total_backlog = sum(backlog(:, d));
        detailedSheet{row, 7} = total_backlog;
        
        % Status
        if total_backlog > 0
            detailedSheet{row, 8} = '⚠️ BACKLOG';
        elseif total_release > capacity(d)
            detailedSheet{row, 8} = '⚠️ PREKORAČEN KAPACITET';
        elseif utilization > 90
            detailedSheet{row, 8} = '✓ VISOKO ISKORIŠĆENJE';
        elseif utilization < 50
            detailedSheet{row, 8} = '⚠️ NISKO ISKORIŠĆENJE';
        else
            detailedSheet{row, 8} = '✓ OK';
        end
    end
    
    % Dodaj sume
    total_row = numDays + 4;
    detailedSheet{total_row, 1} = 'UKUPNO';
    detailedSheet{total_row, 3} = sum(sum(demand));
    detailedSheet{total_row, 4} = sum(sum(release));
    detailedSheet{total_row, 6} = sum(sum(inventory));
    detailedSheet{total_row, 7} = sum(sum(backlog));
    
    % Dodaj prosečno iskorišćenje
    avg_utilization = mean(cell2mat(detailedSheet(4:numDays+3, 5)));
    detailedSheet{total_row, 5} = sprintf('%.1f%%', avg_utilization);
    
    writecell(detailedSheet, filename, 'Sheet', 'Detaljan Izveštaj');
end

function cellData = safeConvertCells(cellData)
    for i = 1:size(cellData,1)
        for j = 1:size(cellData,2)
            try
                element = cellData{i,j};
                
                if isempty(element) || (isstring(element) && ismissing(element))
                    cellData{i,j} = '';
                elseif isnumeric(element) && any(isnan(element(:)))
                    cellData{i,j} = '';
                elseif iscell(element)
                    if ~isempty(element)
                        firstElem = element{1};
                        if isempty(firstElem) || (isstring(firstElem) && ismissing(firstElem))
                            cellData{i,j} = '';
                        elseif isnumeric(firstElem) && any(isnan(firstElem(:)))
                            cellData{i,j} = '';
                        else
                            cellData{i,j} = firstElem;
                        end
                    else
                        cellData{i,j} = '';
                    end
                end
            catch
                cellData{i,j} = '';
            end
        end
    end
end

function makeImprovedPlots(pnCount, numDays, demand, release, inventory, backlog, capacity, dayToWeek, dayNames)
    figure('Position', [100, 100, 1400, 900]);
    
    numWeeks = max(dayToWeek);
    
    % 1. Kapacitet vs Proizvodnja (nedeljno)
    subplot(3,3,1);
    weekly_capacity = zeros(1, numWeeks);
    weekly_production = zeros(1, numWeeks);
    
    for w = 1:numWeeks
        weekDays = find(dayToWeek == w);
        weekly_capacity(w) = sum(capacity(weekDays));
        weekly_production(w) = sum(sum(release(:, weekDays)));
    end
    
    bar(1:numWeeks, weekly_capacity, 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none');
    hold on;
    bar(1:numWeeks, weekly_production, 'FaceColor', [0.2 0.6 0.8], 'FaceAlpha', 0.7);
    
    xlabel('Nedelja (CW)');
    ylabel('Količina');
    title('Nedeljni kapacitet vs proizvodnja');
    legend('Kapacitet', 'Proizvodnja', 'Location', 'best');
    grid on;
    
    % 2. Backlog po nedeljama
    subplot(3,3,2);
    weekly_backlog = zeros(1, numWeeks);
    
    for w = 1:numWeeks
        weekDays = find(dayToWeek == w);
        weekly_backlog(w) = sum(sum(backlog(:, weekDays)));
    end
    
    if sum(weekly_backlog) > 0
        bar(1:numWeeks, weekly_backlog, 'FaceColor', [0.8 0.2 0.2]);
        xlabel('Nedelja (CW)');
        ylabel('Backlog');
        title('Backlog po nedeljama');
        grid on;
    else
        text(0.5, 0.5, '✅ NEMA BACKLOG-A', 'HorizontalAlignment', 'center', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Color', 'green');
        title('Backlog po nedeljama');
        axis off;
    end
    
    % 3. Zalihe po nedeljama
    subplot(3,3,3);
    weekly_inventory = zeros(1, numWeeks);
    
    for w = 1:numWeeks
        weekDays = find(dayToWeek == w);
        weekly_inventory(w) = sum(sum(inventory(:, weekDays)));
    end
    
    bar(1:numWeeks, weekly_inventory, 'FaceColor', [0.2 0.8 0.4]);
    xlabel('Nedelja (CW)');
    ylabel('Zalihe');
    title('Zalihe po nedeljama');
    grid on;
    
    % 4. Dnevna iskorišćenost (%)
    subplot(3,3,4);
    daily_utilization = zeros(1, numDays);
    
    for d = 1:numDays
        daily_utilization(d) = sum(release(:, d)) / capacity(d) * 100;
    end
    
    % Prikaži prvih 21 dan radi preglednosti
    showDays = min(21, numDays);
    bar(1:showDays, daily_utilization(1:showDays));
    hold on;
    yline(100, 'r--', '100% Kapacitet', 'LineWidth', 1.5);
    yline(90, 'g--', 'Cilj 90%', 'LineWidth', 1);
    
    xlabel('Dan');
    ylabel('Iskorišćenost (%)');
    title('Dnevna iskorišćenost kapaciteta');
    ylim([0 120]);
    grid on;
    
    % 5. Top 5 PN sa najviše proizvodnje unapred
    subplot(3,3,5);
    
    early_production = zeros(pnCount, 1);
    for p = 1:pnCount
        for d = 1:numDays
            if release(p, d) > 0
                % Proveri da li postoji tražnja u naredna 2 dana
                early_flag = false;
                for future = d+1:min(d+2, numDays)
                    if demand(p, future) > 0
                        early_production(p) = early_production(p) + release(p, d);
                        early_flag = true;
                        break;
                    end
                end
            end
        end
    end
    
    [sorted_early, idx] = sort(early_production, 'descend');
    top_n = min(5, pnCount);
    
    if top_n > 0 && max(sorted_early) > 0
        barh(1:top_n, sorted_early(1:top_n), 'FaceColor', [0.4 0.6 0.8]);
        ylabel('PN');
        xlabel('Proizvodnja unapred');
        title('Top 5 PN sa proizvodnjom unapred');
        yticks(1:top_n);
        yticklabels(arrayfun(@(x) sprintf('PN-%d', idx(x)), 1:top_n, 'UniformOutput', false));
        grid on;
    else
        text(0.5, 0.5, 'Nema proizvodnje unapred', 'HorizontalAlignment', 'center');
        title('Top 5 PN sa proizvodnjom unapred');
        axis off;
    end
    
    % 6. Distribucija proizvodnje po danima u nedelji
    subplot(3,3,6);
    production_by_day = zeros(1, 7);
    
    for d = 1:numDays
        day_of_week = mod(d-1, 7) + 1;
        production_by_day(day_of_week) = production_by_day(day_of_week) + sum(release(:, d));
    end
    
    bar(1:7, production_by_day, 'FaceColor', [0.6 0.4 0.8]);
    xticks(1:7);
    xticklabels(dayNames);
    xlabel('Dan u nedelji');
    ylabel('Ukupna proizvodnja');
    title('Proizvodnja po danima u nedelji');
    grid on;
    
    % 7. Backlog po PN (top 5)
    subplot(3,3,7);
    backlog_per_pn = sum(backlog, 2);
    [sorted_backlog, idx] = sort(backlog_per_pn, 'descend');
    top_n = min(5, pnCount);
    
    if top_n > 0 && max(sorted_backlog) > 0
        barh(1:top_n, sorted_backlog(1:top_n), 'FaceColor', [0.8 0.4 0.2]);
        ylabel('PN');
        xlabel('Backlog');
        title('Top 5 PN sa backlog-om');
        yticks(1:top_n);
        yticklabels(arrayfun(@(x) sprintf('PN-%d', idx(x)), 1:top_n, 'UniformOutput', false));
        grid on;
    else
        text(0.5, 0.5, '✅ NEMA BACKLOG-A', 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'FontWeight', 'bold', 'Color', 'green');
        title('Top 5 PN sa backlog-om');
        axis off;
    end
    
    % 8. Proizvodnja vs Tražnja za prva 3 PN
    subplot(3,3,8);
    colors = lines(3);
    
    for p = 1:min(3, pnCount)
        plot(1:numDays, demand(p,:), '--', 'Color', colors(p,:), 'LineWidth', 1);
        hold on;
        plot(1:numDays, release(p,:), '-', 'Color', colors(p,:), 'LineWidth', 2);
    end
    
    xlabel('Dan');
    ylabel('Količina');
    title('Tražnja vs Proizvodnja (prva 3 PN)');
    legend('PN1 Tražnja', 'PN1 Proizvodnja', 'PN2 Tražnja', 'PN2 Proizvodnja', ...
        'PN3 Tražnja', 'PN3 Proizvodnja', 'Location', 'best');
    grid on;
    
    % 9. Kretanje zaliha za prva 3 PN
    subplot(3,3,9);
    
    for p = 1:min(3, pnCount)
        plot(1:numDays, inventory(p,:), '-', 'Color', colors(p,:), 'LineWidth', 2);
        hold on;
    end
    
    xlabel('Dan');
    ylabel('Zalihe');
    title('Kretanje zaliha (prva 3 PN)');
    legend('PN1', 'PN2', 'PN3', 'Location', 'best');
    grid on;
    
    sgtitle('KOMPLETNA ANALIZA POBOLJŠANOG PLANA', 'FontSize', 16, 'FontWeight', 'bold');
    
    saveas(gcf, 'poboljsani_plan_grafika.png');
    fprintf('✅ Grafikoni sačuvani kao "poboljsani_plan_grafika.png"\n');
end
