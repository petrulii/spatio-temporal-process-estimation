function [] = test2()
    r = 10;
    eps = 0.7;
    x_init = r*eps/2;
    [approx, x] = approximate(r, eps, x_init);
    n = 20;
    x = linspace(-10,10,n);
    y = zeros(1,n);
    for i = 1:20
        y(i) = find_sup(r, approx, x(i));
    end
    hold on;
    plot(x,y, '.');
    plot(x, lse(x), '-');
    hold off;
end

function y = lse(x)
    y = log(1+exp(x));
end

function [y_max] = find_sup(r, approx, x)
    y_max = -1000;
    for k = 1:r
        a_k = approx(k,1);
        b_k = approx(k,2);
        y = a_k*x+b_k;
        if y>y_max
            y_max = y;
        end
    end
end

function [approx, x] = approximate(r, eps, x_init)
    approx = zeros(r+1,2);
    x = zeros(1,r);
    x_k = -x_init;
    for k = 1:r
        % Find the tangent line.
        a_k = delta(x_k);
        b_k = -x_k.*delta(x_k)+log(exp(x_k)+1);
        approx(k,:) = [a_k, b_k];
        x(k) = x_k;
        x_k = x_k + eps;
    end
    approx(r+1,:) = [0, 0];
end

function [y] = delta(x)
    y = 1.-(1./(exp(x)+1));
end