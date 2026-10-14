function res = solve_plan(demand, capacity, config)
% SOLVE_PLAN  Optimalan dnevni plan puštanja u proizvodnju (MILP).
%
% Za svaki PN p i dan d:
%   x  proizvodnja (ceo broj)
%   S  zalihe do ciljnih sigurnosnih zaliha     cena config.safetyStockCost
%   E  zalihe iznad sigurnosnih (višak)         cena config.excessInventoryCost
%   B  backlog (neisporučena tražnja)           cena config.backlogPenalty
%   U  manjak ispod sigurnosnih zaliha          cena config.safetyShortfallCost
%
%   S + E - B = (S + E - B)[d-1] + x - tražnja    bilans zaliha
%   S + U >= safetyStock,  0 <= S <= safetyStock  meki cilj sigurnosnih zaliha
%   sum_p x(p,d) <= kapacitet(d)                  zajednički dnevni kapacitet
%
% Backlog je najskuplji, pa se proizvodi unapred kad kapacitet ne stiže,
% ali samo onoliko ranije koliko je potrebno, jer svaka jedinica na zalihi košta.
% Potreban je Optimization Toolbox (intlinprog / linprog).

    [P, D] = size(demand);
    K = 5;                       % blokovi promenljivih: x, S, E, B, U
    n = P * D * K;
    X = 0; S = 1; E = 2; B = 3; U = 4;
    idx = @(block, p, d) (block * P + (p - 1)) * D + d;

    f = zeros(n, 1);
    f(S*P*D+1:(S+1)*P*D) = config.safetyStockCost;
    f(E*P*D+1:(E+1)*P*D) = config.excessInventoryCost;
    f(B*P*D+1:(B+1)*P*D) = config.backlogPenalty;
    f(U*P*D+1:(U+1)*P*D) = config.safetyShortfallCost;

    lb = zeros(n, 1);
    ub = inf(n, 1);
    ub(S*P*D+1:(S+1)*P*D) = config.safetyStock;

    % bilans zaliha (jednakosti): 4 ili 7 nenultih po redu
    nnzEq = P * (4 + 7 * (D - 1));
    ri = zeros(nnzEq, 1); ci = ri; vi = ri; k = 0;
    beq = zeros(P * D, 1);
    r = 0;
    for p = 1:P
        for d = 1:D
            r = r + 1;
            cols = [idx(S,p,d), idx(E,p,d), idx(B,p,d), idx(X,p,d)];
            vals = [1, 1, -1, -1];
            beq(r) = -demand(p, d);
            if d > 1
                cols = [cols, idx(S,p,d-1), idx(E,p,d-1), idx(B,p,d-1)]; %#ok<AGROW>
                vals = [vals, -1, -1, 1]; %#ok<AGROW>
            else
                beq(r) = beq(r) + config.initialInventory;
            end
            m = numel(cols);
            ri(k+1:k+m) = r; ci(k+1:k+m) = cols; vi(k+1:k+m) = vals; k = k + m;
        end
    end
    Aeq = sparse(ri(1:k), ci(1:k), vi(1:k), P * D, n);

    % nejednakosti: -(S + U) <= -safetyStock, i kapacitet
    ri = zeros(2*P*D + P*D, 1); ci = ri; vi = ri; k = 0;
    b = zeros(P*D + D, 1);
    r = 0;
    for p = 1:P
        for d = 1:D
            r = r + 1;
            ri(k+1:k+2) = r; ci(k+1:k+2) = [idx(S,p,d), idx(U,p,d)]; vi(k+1:k+2) = -1; k = k + 2;
            b(r) = -config.safetyStock;
        end
    end
    for d = 1:D
        r = r + 1;
        for p = 1:P
            k = k + 1; ri(k) = r; ci(k) = idx(X,p,d); vi(k) = 1;
        end
        b(r) = capacity(d);
    end
    A = sparse(ri(1:k), ci(1:k), vi(1:k), P*D + D, n);

    if config.useInteger
        intcon = 1:P*D;
        options = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', config.maxTime);
        [xsol, fval, exitflag] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, options);
    else
        options = optimoptions('linprog', 'Display', 'off');
        [xsol, fval, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, options);
    end
    if exitflag <= 0
        error('Optimizacija nije uspela (exitflag = %d).', exitflag);
    end

    block = @(blk) reshape(xsol(blk*P*D+1:(blk+1)*P*D), D, P)';
    res.release = block(X);
    if config.useInteger
        res.release = round(res.release);
    end
    net = block(S) + block(E) - block(B);
    net = round(net * 1e6) / 1e6;
    res.inventory = max(net, 0);
    res.backlog = max(-net, 0);
    res.objective = fval;
end
