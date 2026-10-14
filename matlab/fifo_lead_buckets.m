function out = fifo_lead_buckets(release, demand, initialInventory)
% FIFO_LEAD_BUCKETS  Koliko dana pre roka je proizvedena svaka jedinica (FIFO).
%   out(p,:) = [isti dan, 1 dan ranije, 2 dana ranije, 3+ dana ranije, kasni]
%   Jedinice koje do kraja horizonta nisu isporučene računaju se kao kasne.

    if nargin < 3, initialInventory = 0; end
    [P, D] = size(demand);
    out = zeros(P, 5);
    for p = 1:P
        lots = zeros(0, 2);      % [dan proizvodnje, količina]
        if initialInventory > 0
            lots = [-1e6, initialInventory];
        end
        orders = zeros(0, 2);    % [dan roka, količina]
        for d = 1:D
            if release(p, d) > 0, lots(end+1, :) = [d, release(p, d)]; end %#ok<AGROW>
            if demand(p, d) > 0, orders(end+1, :) = [d, demand(p, d)]; end %#ok<AGROW>
            while ~isempty(lots) && ~isempty(orders)
                q = min(lots(1, 2), orders(1, 2));
                early = orders(1, 1) - lots(1, 1);
                if early < 0
                    out(p, 5) = out(p, 5) + q;
                else
                    bucket = min(early, 3) + 1;
                    out(p, bucket) = out(p, bucket) + q;
                end
                lots(1, 2) = lots(1, 2) - q;
                orders(1, 2) = orders(1, 2) - q;
                if lots(1, 2) <= 1e-9, lots(1, :) = []; end
                if orders(1, 2) <= 1e-9, orders(1, :) = []; end
            end
        end
        out(p, 5) = out(p, 5) + sum(orders(:, 2));
    end
end
