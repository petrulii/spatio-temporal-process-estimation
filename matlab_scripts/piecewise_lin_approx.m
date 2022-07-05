function [] = test2()
    r = 20;
    eps = 0.7;
    x_init = r*eps/2;
    [approx, x] = lse_lin_approx(r, eps, x_init);
    n = 20;
    x = linspace(-30,30,n);
    y = zeros(1,n);
    for i = 1:20
        y(i) = approximate_lse(r, approx, x(i));
        disp(size(approx));
        x_ = [x(i) 1];
        disp(size(x_));
        disp(max(approx*x_.'));
        disp(y(i));
    end
    figure('visible','on');
    hold on;
    plot(x,y, '.');
    plot(x, lse(x), '-');
    title('Piecewise-Linear Approximation');
    xlabel('x');
    ylabel('f(x)');
    legend('Approximation','log(1+exp(x))');
    hold off;
end

function y = lse(x)
    y = log(1+exp(x));
end