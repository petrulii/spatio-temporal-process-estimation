% Main function.
function main
    % Set the random seed.
    rng('default')
    % Set the solver
    %cvx_solver sedumi
    % Memory depth.
    d = 3;
    periods = 4;
    error_log = [];
    error_lin = [];
    zer = [];
    %dimension = [];
    all_lambda = [];
    row = 3;
    col = 3;
    for lambda = 0:0.0000001:0.0000003%5
        density = (d)/(periods*row*col);
        fprintf('%s %d %s %d\n', 'Initial density of the series:', density, 'lambda:', lambda);
        % Generating Bernouilli time series of N time instances and L locations.
        [time_horizon, N, L, true_theta, true_b] = generate_series(row, col, d, periods, density);
        disp(time_horizon(1:8,1:8));
        % Inferring theta, the parameter vector of the time series.
        [theta, b] = logistic(time_horizon, N, L, d, lambda);
        % Transform small values of theta to 0s.
        theta(theta>-0.0001 & theta<0.0001) = 0;
        % Generate a prediction and compare with groud truth.
        [err_log, z] = predict(time_horizon((N-d)+1:N,:), time_horizon(N+1,:), L, true_theta, theta, b, row, col, @sigmoid, false, d);
        error_log = [error_log err_log];
        zer = [zer z];
        % Inferring theta, the parameter vector of the time series.
        [theta, b] = linear(time_horizon, N, L, d, lambda);
        % Transform small values of theta to 0s.
        theta(theta>-0.0001 & theta<0.0001) = 0;
        % Generate a prediction and compare with groud truth.
        [err_lin, ~] = predict(time_horizon((N-d)+1:N,:), time_horizon(N+1,:), L, true_theta, theta, b, row, col, @identity, false, d);
        error_lin = [error_lin err_lin];
        all_lambda = [all_lambda lambda];
        %dimension = [dimension row*col];
    end
    plot(all_lambda, zer);
    xlabel('\lambda');
    ylabel('Zero count in \theta');
    saveas(gcf, 'distance', 'png');
    plot(all_lambda, error_log);
    xlabel('\lambda');
    ylabel('Log-regression error at t+1');
    saveas(gcf, 'error_log', 'png');
    plot(all_lambda, error_lin);
    xlabel('\lambda');
    ylabel('Linear-regression error at t+1');
    saveas(gcf, 'error_lin', 'png');
end

function [theta, bias] = logistic(time_horizon, N, L, d, lambda)
        n = L*L*d;
        cvx_begin
            variable theta(L, d*L);
            variable bias(L);
            obj = 0;
            for s = d:N
                X = time_horizon((s-d+1):s,:);
                X = reshape(X.',1,[]);
                for l = 1:L
                    y = time_horizon(s+1,l);
                    a = theta(l,:);
                    b = bias(l);
                    % Log-likelihood with L1 penalty.
                    obj = obj + (y'*(dot(X,a)+b)-sum(log_sum_exp([0; (dot(X',a')+b)])))/(n) - lambda * sum(abs(a));
                end
            end
            maximize(obj);
        cvx_end
end

function [theta, bias] = linear(time_horizon, N, L, d, lambda)
        n = L*L*d;
        cvx_begin
            variable theta(L, d*L);
            variable bias(L);
            obj = 0;
            for s = d:N
                X = time_horizon((s-d+1):s,:);
                X = reshape(X.',1,[]);
                for l = 1:L
                    y = time_horizon(s+1,l);
                    a = theta(l,:);
                    b = bias(l);
                    % Log-likelihood with L1 penalty.
                    obj = obj + norm(y-(dot(X,a)+b))/2 + lambda * sum(abs(a));
                end
            end
            minimize(obj);
        cvx_end
end

% Prediction for time series of 2-D Bernouilli events.
function [err, zer] = predict(X, y, L, true_theta, theta, b, rows, columns, activation, heatmap, d)
    if ~exist('heatmap','var')
        heatmap = false; end
    X = reshape(X.',1,[]);
    y = reshape(y.',1,[]);
    prediction = normrnd(0,1,1,L);
    obj = 0;
    norm1 = 0;
    zer = 0;
    for l = 1:L
        prediction(l) = activation(b(l) + dot(X, theta(l,:)));
        a = theta(l,:);
        obj = obj + (y(l)'*(dot(X,a)+b(l))-sum(log_sum_exp([0; (dot(X',a')+b(l))])))/(L*L*d);
        norm1 = norm1 + sum(abs(true_theta(l,:)));
        zer = zer + sum(a==0);
    end
    % Calculate the error of the prediction.
    err = immse(y,prediction);
    dist = norm((true_theta-theta),2);
    fprintf('%s %d %s %d %s %d %s %d %s %d\n', 'Prediction error:', err, 'distance between estimation and true parameters:', dist, 'zero count:', zer, 'likelihood:', obj, 'l1 norm:', norm1);
    disp(theta(1,1:3));
    disp(true_theta(1,1:3));
    % Plot the ground truth and prediction heatmaps.
    if heatmap == true
        y = reshape(y,rows,columns);
        colormap('hot');
        imagesc(y);
        colorbar;
        fig1 = gcf;
        saveas(fig1,'ground_truth','png');
        prediction = reshape(prediction,rows,columns);
        colormap('hot');
        imagesc(prediction);
        colorbar;
        fig2 = gcf;
        saveas(fig2,'prediction','png');
    end
end

% Log-it activation function.
function y = sigmoid(x)
    y = 1/(1+exp(-x));
end

% Identity activation function.
function y = identity(x)
    y = x;
end

% Binary log-it activation function.
function y = binary_sigmoid(x)
    if (1/(1+exp(-x))) >= 0.5
        y = 1;
    else
        y = 0;
    end
end

% Generate time series with d*periods+1 time steps,
% where the value at time t is an L_rows*L_columns
% binary matrix of specified density.
function [time_horizon, N, L, theta, b] = generate_series(L_rows, L_columns, d, periods, density)
    L = L_rows*L_columns;
    % Creating random events with some density over an n by m grid.
    N = d + d*periods;
    % Initialiazing the time horizon.
    time_horizon = zeros(N,L);
    % Create a random Bernoulli process grid at the initial time strech.
    for s = (1:d)
        x = sprand(L, 1, density);
        x(x>0) = 1;
        for l = 1:L
            time_horizon(s,:) = x;
        end
    end
    % Initialising the true parameter vector and the bias.
    theta = normrnd(0, 1, L, d*L);
    %theta = sprandn(L, d*L, (d/(d*L)));
    b = normrnd(0, 1, 1, L);
    % Generate time series.
    for s = (d+1):(N+1)
        % Predictor X of dimension d*L.
        X = time_horizon((s-d):(s-1),:);
        X = reshape(X.',1,[]);
        for l = 1:L
            % Train data.
            if s ~= (N+1)
                time_horizon(s,l) = binary_sigmoid(b(l) + dot(X, theta(l,:)));
            % Test data.
            else
                time_horizon(s,l) = sigmoid(b(l) + dot(X, theta(l,:)));
            end
        end
    end
end