function inp = parse_plan_input(raw)
% PARSE_PLAN_INPUT  Izvlači tražnju i kapacitet iz ćelija ulaznog sheet-a.
%   raw je cell niz kakav vraća readcell. Podaci počinju u koloni C:
%     red sa 'Kapacitet' u koloni C   -> sledeći red je dnevni kapacitet
%     red sa 'Pon','Uto',...          -> nazivi dana (jedna kolona po danu)
%     'PN-...' u koloni A             -> blok jednog PN-a, ispod njega redovi
%        'Planned release', 'Planed order' (tražnja), 'Cummulative'

    dayNames = {'Pon','Uto','Sre','Cet','Pet','Sub','Ned'};
    firstCol = 3;
    [nRows, nCols] = size(raw);

    % red sa danima
    dayRow = [];
    for r = 1:min(30, nRows)
        if any(strcmp(cell_text(raw, r, firstCol), dayNames))
            dayRow = r;
            break;
        end
    end
    if isempty(dayRow)
        error('Nije pronađen red sa danima (Pon, Uto, ...) u koloni C.');
    end
    inp.dayNames = {};
    for c = firstCol:nCols
        v = cell_text(raw, dayRow, c);
        if ~any(strcmp(v, dayNames)), break; end
        inp.dayNames{end+1} = v;
    end
    numDays = numel(inp.dayNames);

    % red sa kapacitetom
    capRow = [];
    for r = 1:dayRow-1
        if strcmpi(cell_text(raw, r, firstCol), 'Kapacitet')
            capRow = r;
            break;
        end
    end
    if isempty(capRow)
        error('Nije pronađen red ''Kapacitet'' iznad reda sa danima.');
    end
    inp.capacity = zeros(1, numDays);
    for d = 1:numDays
        inp.capacity(d) = cell_num(raw, capRow + 1, firstCol + d - 1);
    end

    % PN blokovi
    inp.pnNames = {};
    inp.demand = zeros(0, numDays);
    inp.releaseRows = [];
    inp.cumulativeRows = [];
    for r = dayRow+1:nRows
        name = cell_text(raw, r, 1);
        if numel(name) < 3 || ~strcmp(name(1:3), 'PN-'), continue; end
        orderRow = 0; releaseRow = 0; cumRow = 0;
        for k = 1:3
            label = lower(cell_text(raw, r + k, 1));
            if contains(label, 'release'),   releaseRow = r + k;
            elseif contains(label, 'order'), orderRow = r + k;
            elseif contains(label, 'cum'),   cumRow = r + k;
            end
        end
        if orderRow == 0
            error('%s (red %d) nema red ''Planed order''.', name, r);
        end
        row = zeros(1, numDays);
        for d = 1:numDays
            row(d) = cell_num(raw, orderRow, firstCol + d - 1);
        end
        inp.pnNames{end+1} = name;
        inp.demand(end+1, :) = row;
        inp.releaseRows(end+1) = releaseRow;
        inp.cumulativeRows(end+1) = cumRow;
    end
    if isempty(inp.pnNames)
        error('Nisu pronađeni PN-... redovi.');
    end

    % nedelja počinje svakim ponedeljkom posle prvog dana
    inp.weekOfDay = cumsum([1, strcmp(inp.dayNames(2:end), 'Pon')]);
    inp.firstCol = firstCol;
end

function s = cell_text(raw, r, c)
    s = '';
    if r > size(raw, 1) || c > size(raw, 2), return; end
    v = raw{r, c};
    if isstring(v) && ~ismissing(v), v = char(v); end
    if ischar(v), s = strtrim(v); end
end

function x = cell_num(raw, r, c)
    x = 0;
    if r > size(raw, 1) || c > size(raw, 2), return; end
    v = raw{r, c};
    if isnumeric(v) && isscalar(v) && ~isnan(v)
        x = double(v);
    elseif ischar(v) || (isstring(v) && ~ismissing(v))
        n = str2double(v);
        if ~isnan(n), x = n; end
    end
end
