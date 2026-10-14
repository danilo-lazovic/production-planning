function write_plan_report(filename, raw, inp, res, buckets)
% WRITE_PLAN_REPORT  Upisuje plan u kopiju ulaznog sheet-a i dodaje analize.
%   Sheet-ovi: Plan, Dnevni pregled, Nedeljni pregled, Backlog, Proizvodnja unapred.

    [P, D] = size(inp.demand);
    net = res.inventory - res.backlog;

    % 1. Plan: ulazni sheet sa popunjenim 'Planned release' i 'Cummulative'
    plan = raw;
    for i = 1:numel(plan)
        v = plan{i};
        if (isnumeric(v) && isscalar(v) && isnan(v)) || (isstring(v) && ismissing(v)) ...
                || isa(v, 'missing')
            plan{i} = '';
        end
    end
    for p = 1:P
        for d = 1:D
            c = inp.firstCol + d - 1;
            if inp.releaseRows(p) > 0, plan{inp.releaseRows(p), c} = res.release(p, d); end
            if inp.cumulativeRows(p) > 0, plan{inp.cumulativeRows(p), c} = net(p, d); end
        end
    end
    if exist(filename, 'file'), delete(filename); end
    writecell(plan, filename, 'Sheet', 'Plan');

    produced = sum(res.release, 1);
    dem = sum(inp.demand, 1);
    inv = sum(res.inventory, 1);
    bl = sum(res.backlog, 1);

    % 2. Dnevni pregled
    daily = {'Dan', 'Nedelja', 'Dan u nedelji', 'Kapacitet', 'Tražnja', 'Proizvodnja', ...
             'Iskorišćenost (%)', 'Zalihe', 'Backlog', 'Status'};
    for d = 1:D
        if inp.capacity(d) > 0
            util = round(produced(d) / inp.capacity(d) * 1000) / 10;
        else
            util = '';
        end
        if bl(d) > 0
            status = 'BACKLOG';
        elseif inp.capacity(d) > 0 && produced(d) > inp.capacity(d)
            status = 'PREKORAČENJE';
        else
            status = 'OK';
        end
        daily(end+1, :) = {d, sprintf('CW%02d', inp.weekOfDay(d)), inp.dayNames{d}, ...
            inp.capacity(d), dem(d), produced(d), util, inv(d), bl(d), status}; %#ok<AGROW>
    end
    writecell(daily, filename, 'Sheet', 'Dnevni pregled');

    % 3. Nedeljni pregled
    weekly = {'Nedelja', 'Kapacitet', 'Tražnja', 'Proizvodnja', 'Iskorišćenost (%)', ...
              'Zalihe na kraju', 'Backlog na kraju'};
    for w = unique(inp.weekOfDay)
        m = find(inp.weekOfDay == w);
        cap = sum(inp.capacity(m));
        weekly(end+1, :) = {sprintf('CW%02d', w), cap, sum(dem(m)), sum(produced(m)), ...
            round(sum(produced(m)) / cap * 1000) / 10, inv(m(end)), bl(m(end))}; %#ok<AGROW>
    end
    writecell(weekly, filename, 'Sheet', 'Nedeljni pregled');

    % 4. Backlog po PN i danu
    header = [{'PN'}, arrayfun(@(d) sprintf('D%02d', d), 1:D, 'UniformOutput', false)];
    writecell([header; [inp.pnNames(:), num2cell(round(res.backlog))]], filename, 'Sheet', 'Backlog');

    % 5. Proizvodnja unapred (FIFO)
    early = {'PN', 'Tražnja', 'Proizvodnja', 'Isti dan', '1 dan ranije', '2 dana ranije', ...
             '3+ dana ranije', 'Kasni (backlog)', '% unapred'};
    for p = 1:P
        total = sum(buckets(p, :));
        pct = 0;
        if total > 0, pct = round(sum(buckets(p, 2:4)) / total * 1000) / 10; end
        early(end+1, :) = [{inp.pnNames{p}, sum(inp.demand(p, :)), sum(res.release(p, :))}, ...
            num2cell(round(buckets(p, :))), {pct}]; %#ok<AGROW>
    end
    writecell(early, filename, 'Sheet', 'Proizvodnja unapred');
end
