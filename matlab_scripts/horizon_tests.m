% Main function.
function horizon_tests
    % Set the random seed.
    rng(0);
    % Memory depth.
    d = 3;
    % The length of the time horizon is d*periods+1.
    periods = 100;
    % Dimensions of 2-D space at any time instance.
    row = 10;
    col = row;
    % Determine density.
    density = 0.01;
    % Generating Bernouilli time series of N time instances and L locations.
    [time_horizon, N, L, true_theta, true_b] = generate_series(row, col, d, periods, density);
end

function y = sigmoid(x)
    y = (1+exp(-x)).^(-1);
end

% Bernouilli draw with probability p.
function y = Bernouilli_draw(p)
    r = rand();
    if r <= p
        y = 1;
    else
        y = 0;
    end
end

function [time_horizon, N, L, theta, theta0] = generate_series(L_rows, L_columns, d, periods, density)
    % Number of locations.
    L = L_rows*L_columns;
    % Length of the time horizon.
    N = d + d*periods;
    % For plotting.
    norm_X = zeros(1,N+1);
    norm_probability = zeros(1,N+1);
    % Initialiazing the time horizon.
    time_horizon = zeros(N,L);
    % Create a random Bernoulli process grid at the initial time strech.
    for s = (1:d)
        x = sprand(L, 1, density);
        x(x>0) = 1;
        norm_X(1,s) = norm_X(1,s) + norm(x,2);
        for l = 1:L
            time_horizon(s,:) = x;
        end
    end
    % Initialising the sparse true parameter vector and the initial probability.
    theta = sprandn(L, d*L, density);
    fprintf('%s\n %d\n', 'Part of non-zero values in the true parameter vector:', nnz(theta)/(d*L*L));
    % Putting half of the true parameter vector values below 0.
    theta0 = normrnd(0, 1, 1, L);
    % Generate time series.
    for s = (d+1):(N+1)
        % Predictor X of dimension d*L.
        X = time_horizon((s-d):(s-1),:);
        X = reshape(X.',1,[]);
        for l = 1:L
            % Probability of the event.
            p = sigmoid(theta0(l) + dot(X, theta(l,:)));
            % Bernouilli event.
            time_horizon(s,l) = Bernouilli_draw(p);
            % Calculating the 2-norms.
            norm_probability(1,s) = norm_probability(1,s) + p^2;
            norm_X(1,s) = norm_X(1,s) + time_horizon(s,l);
        end
    end
    fprintf('%s\n %d\n', 'Part of non-zero values in the time horizon:', nnz(time_horizon)/(N*L));
    % Plotting
    time = 1:(N+1);
    base_proba = sigmoid(theta0);
    norm_theta0 = repelem(sqrt(sum(base_proba.^2)), N+1);
    norm_probability = sqrt(norm_probability);
    norm_X = sqrt(norm_X);
    figure(1);
    hold on;
    plot(time, norm_theta0);
    plot(time, norm_probability);
    plot(time, norm_X);
    xlabel('Time t');
    ylabel('2-norm');
    legend('base probabilites at time t : p0^{1,...,L}_t','probabilities at time t : p^{1,...,L}_t','events at time t : y^{1,...,L}_t');
    saveas(gcf, 'time_horizon_vs_initial_intensities', 'png');
    hold off;
    color_plot(time_horizon(d*d,:),time_horizon(d*d+1,:), L_rows);
end

function [] = color_plot(v_true,v_pred,n)
    v_true = reshape(v_true,n,n);
    v_pred = reshape(v_pred,n,n);
    bottom = min(min(min(v_true)),min(min(v_pred)));
    top  = max(max(max(v_true)),max(max(v_pred)));
    f = figure('visible','off');
    % Plotting the first plot
    sp1 = subplot(1,2,1);
    colormap('hot');
    imagesc(v_true);
    xlabel(sp1, 'X at time t');
    shading interp;
    % This sets the limits of the colorbar to manual for the first plot
    caxis manual;
    caxis([bottom top]);
    % Plotting the second plot
    sp2 = subplot(1,2,2);
    colormap('hot');
    imagesc(v_pred);
    xlabel(sp2, 'X at time t+1');
    shading interp;
    % This sets the limits of the colorbar to manual for the second plot
    caxis manual;
    caxis([bottom top]);
    colorbar;
    saveas(f, 'color_maps', 'png');
end