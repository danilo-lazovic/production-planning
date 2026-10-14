function plot_plan(inp, res, buckets, pngFile)
% PLOT_PLAN  Dashboard sa 6 grafikona; čuva ga kao PNG.

    weeks = unique(inp.weekOfDay);
    nW = numel(weeks);
    produced = sum(res.release, 1);
    dem = sum(inp.demand, 1);
    inv = sum(res.inventory, 1);
    bl = sum(res.backlog, 1);
    D = numel(produced);

    wCap = zeros(1, nW); wDem = wCap; wProd = wCap; wInv = wCap; wBl = wCap;
    for i = 1:nW
        m = find(inp.weekOfDay == weeks(i));
        wCap(i) = sum(inp.capacity(m)); wDem(i) = sum(dem(m)); wProd(i) = sum(produced(m));
        wInv(i) = inv(m(end)); wBl(i) = bl(m(end));
    end
    wl = arrayfun(@(w) sprintf('CW%02d', w), weeks, 'UniformOutput', false);

    fig = figure('Position', [100, 100, 1500, 850]);

    subplot(2,3,1);
    bar([wCap; wDem; wProd]');
    set(gca, 'XTick', 1:nW, 'XTickLabel', wl);
    legend('Kapacitet', 'Tražnja', 'Proizvodnja', 'Location', 'best');
    title('Nedeljno: kapacitet, tražnja, proizvodnja'); grid on;

    subplot(2,3,2);
    h = bar([wInv; wBl]');
    set(h(1), 'FaceColor', [0.30 0.69 0.31]); set(h(2), 'FaceColor', [0.85 0.33 0.31]);
    set(gca, 'XTick', 1:nW, 'XTickLabel', wl);
    legend('Zalihe', 'Backlog', 'Location', 'best');
    title('Zalihe i backlog na kraju nedelje'); grid on;

    subplot(2,3,3);
    util = zeros(1, D);
    has = inp.capacity > 0;
    util(has) = produced(has) ./ inp.capacity(has) * 100;
    bar(1:D, util); hold on;
    plot([0 D+1], [100 100], 'r--', 'LineWidth', 1.2);
    ylim([0 115]); xlabel('Dan');
    title('Dnevna iskorišćenost kapaciteta (%)'); grid on;

    subplot(2,3,4);
    stairs(1:D, cumsum(dem), 'LineWidth', 1.5); hold on;
    stairs(1:D, cumsum(produced), 'LineWidth', 1.5);
    stairs(1:D, cumsum(inp.capacity), ':', 'LineWidth', 1.2);
    legend('Kumulativna tražnja', 'Kumulativna proizvodnja', 'Kumulativni kapacitet', 'Location', 'northwest');
    xlabel('Dan'); title('Kumulativno'); grid on;

    subplot(2,3,5);
    bar(sum(buckets, 1));
    set(gca, 'XTick', 1:5, 'XTickLabel', {'Isti dan', '1 dan', '2 dana', '3+ dana', 'Kasni'});
    title('Koliko ranije je proizvedeno (jedinice, FIFO)'); grid on;

    subplot(2,3,6);
    earlyPerPn = sum(buckets(:, 2:4), 2);
    [~, order] = sort(earlyPerPn, 'descend');
    top = flipud(order(1:min(5, numel(order))));
    barh(1:numel(top), [earlyPerPn(top), buckets(top, 5)], 'stacked');
    set(gca, 'YTick', 1:numel(top), 'YTickLabel', inp.pnNames(top));
    legend('Unapred', 'Kasni', 'Location', 'southeast');
    title('Top 5 PN po proizvodnji unapred'); grid on;

    saveas(fig, pngFile);
end
