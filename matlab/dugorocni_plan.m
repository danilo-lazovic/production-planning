%% Planiranje proizvodnje: dnevni plan puštanja uz ograničen kapacitet
% Pokretanje (iz bilo kog foldera):
%   run('matlab/dugorocni_plan.m')
% Ulaz:  data/primer_ulaz.xlsx (ili svoj fajl, vidi config.inputFile)
% Izlaz: results/plan_<ime ulaza>.xlsx i results/plan_<ime ulaza>.png
% Potrebno: MATLAB R2019a+ i Optimization Toolbox (intlinprog).

clear; clc; close all;

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(here);

%% konfiguracija
config.inputFile = fullfile(root, 'data', 'primer_ulaz.xlsx');
config.outputDir = fullfile(root, 'results');
config.backlogPenalty = 100;        % cena backlog-a po jedinici po danu (najgore)
config.excessInventoryCost = 5;     % cena zaliha iznad sigurnosnih
config.safetyStockCost = 0.1;       % cena sigurnosnih zaliha (skoro besplatne)
config.safetyShortfallCost = 1;     % cena manjka ispod sigurnosnih zaliha
config.safetyStock = 20;            % ciljne sigurnosne zalihe po PN-u
config.initialInventory = 0;        % početne zalihe po PN-u
config.useInteger = true;           % celobrojne količine (intlinprog)
config.maxTime = 300;               % vremensko ograničenje solvera u sekundama

%% učitavanje
raw = readcell(config.inputFile, 'Sheet', 1);
inp = parse_plan_input(raw);
[P, D] = size(inp.demand);
fprintf('Učitano: %d PN, %d dana (%d nedelja), tražnja %d, kapacitet %d\n', ...
    P, D, inp.weekOfDay(end), sum(inp.demand(:)), sum(inp.capacity));

%% optimizacija
res = solve_plan(inp.demand, inp.capacity, config);
buckets = fifo_lead_buckets(res.release, inp.demand, config.initialInventory);

fprintf('Proizvedeno: %d\n', sum(res.release(:)));
fprintf('Backlog (zbir po danima): %d, na kraju: %d\n', round(sum(res.backlog(:))), round(sum(res.backlog(:, end))));
fprintf('Zalihe (zbir po danima): %d\n', round(sum(res.inventory(:))));
fprintf('Isporučeno na vreme: %d, sa kašnjenjem: %d\n', round(sum(sum(buckets(:, 1:4)))), round(sum(buckets(:, 5))));
fprintf('Vrednost funkcije cilja: %.1f\n', res.objective);

%% upozorenja po danima
used = sum(res.release, 1);
for d = find(sum(res.backlog, 1) > 0)
    fprintf('  Dan %02d (%s, CW%02d): backlog %d, proizvodnja %d / %d\n', d, inp.dayNames{d}, ...
        inp.weekOfDay(d), round(sum(res.backlog(:, d))), used(d), inp.capacity(d));
end

%% izlaz
if ~exist(config.outputDir, 'dir'), mkdir(config.outputDir); end
[~, stem] = fileparts(config.inputFile);
xlsxFile = fullfile(config.outputDir, ['plan_' stem '.xlsx']);
pngFile = fullfile(config.outputDir, ['plan_' stem '.png']);
write_plan_report(xlsxFile, raw, inp, res, buckets);
plot_plan(inp, res, buckets, pngFile);
fprintf('\nSačuvano: %s\nSačuvano: %s\n', xlsxFile, pngFile);
