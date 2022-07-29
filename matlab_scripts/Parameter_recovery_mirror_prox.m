function [] = Parameter_recovery_mirror_prox()
    % Set the random seed.
    rng(0);
    % Dimensions of 2-D space grid.
    row = 5;
    col = row;
    % Memeory depth.
    d = 3;
    periods = 1000;
    % Values used in parameter generation.
    radius = 1;
    values = [-1 1];
    % Generating Bernouilli time series of N+1 time instances and L locations.
    [time_series, probabilities, N, L, true_theta, true_theta0] = generate_series(row, col, d, periods, 'operator', radius, values);
    %fprintf('%s %d\n', 'sum of theta :', sum(sum(true_theta)));
    %disp(size(true_theta));
    %return;
    plot_series_one_location(L, N, d, true_theta, true_theta0, 2);
    plot_series(probabilities(4:124,:),120,row,col);
    kappa = 12;
    rate = 1;
    lambda = 0.001;
    max_iterations = 100;
    [theta, theta0, y] = mirror_prox(N, L, d, time_series, kappa, rate, max_iterations, true_theta, true_theta0, lambda);
    %[theta, theta0] = estimate_parameters(N, L, d, time_series, kappa, rate, max_iterations, true_theta, true_theta0, lambda);
    plot_true_pred_series(L, N, d, true_theta, true_theta0, theta, theta0);
end

function [theta, theta0] = estimate_parameters(N, L, d, time_series, kappa, rate, max_iterations, true_theta, true_theta0, lambda)
    max_iterations_kappa = 100;
    left = 0;
    rigth = 0;
    for i = 1:max_iterations_kappa
        if left~=0 && rigth~=0
            % dycothomie
            kappa = (rigth - left)/2;
            [theta, theta0, y] = mirror_prox(N, L, d, time_series, kappa, rate, max_iterations, true_theta, true_theta0, lambda);
            return;
        end
        left = 0;
        rigth = 0;
        [theta, theta0, y] = mirror_prox(N, L, d, time_series, kappa, rate, max_iterations, true_theta, true_theta0, lambda);
        obj = F_kappa(N, L, d, time_series, theta, theta0, y, kappa, lambda);
        if obj > 0
            left = kappa;
            kappa = kappa * 2;
        elseif obj < 0
            rigth = kappa;
            kappa = kappa / 2;
        else
            break;
        end
    end
end

function [theta, theta0, y] = mirror_prox(N, L, d, time_series, kappa, rate, max_iterations, true_theta, true_theta0, lambda)
    % Mirror prox.
    % param N: length of the time horizon of the time series
    % param L: number of locations in the 2D spatial grid
    % param d: memory depth of the process
    % param time_series: time series of the process
    theta = ones(L,d*L);
    theta0 = ones(1,L);
    y = [0 0];

    log_loss_error = zeros(1,max_iterations);
    estimation_error = zeros(1,max_iterations);
    prediction_error = zeros(1,max_iterations);
    i = 1;

    while i <= max_iterations

        fprintf('%s %d\n', 'Iteration :', i);
        fprintf('%s %d\n', 'kappa :', kappa);
        fprintf('%s %d %d\n', 'y0 y1 :', y(1), y(2));
        fprintf('%s %d\n', 'F_0(x) :', neg_log_loss(N, L, d, time_series, theta, theta0) + lambda * l1_norm(theta) - kappa);
        fprintf('%s %d\n', 'F_1(x) :', sum(sum(theta)));
        fprintf('%s %d\n', 'F(kappa) :', F_kappa(N, L, d, time_series, theta, theta0, y, kappa, lambda));
        fprintf('%s %d\n', 'neg log l. :', neg_log_loss(N, L, d, time_series, theta, theta0));
        fprintf('%s %d\n', 'l1_norm(theta) :', l1_norm(theta));
        % FIX THISSSSS!!! true_theta norm should be 0
        fprintf('%s %d\n', 'l1_norm(true_theta) :', l1_norm(true_theta));
        fprintf('%s %d %d %d\n', 'First values of true theta :', true_theta(1,1), true_theta(1,2), true_theta(1,3));
        fprintf('%s %d %d %d\n', 'First values of pred. theta :', theta(1,1), theta(1,2), theta(1,3));

        % Gradient step to go to an intermediate point.
        [theta_grad, theta0_grad] = gradient_theta(N, L, d, time_series, theta, theta0, y, lambda);
        y_grad = gradient_y(N, L, d, time_series, theta, theta0, kappa, lambda);

        % Calculate y_i.
        theta_ = theta - rate*(theta_grad);
        theta0_ = theta0 - rate*(theta0_grad);
        % Project onto the simplex.
        y_ = projsplx(y + rate*(y_grad));

        % Use the gradient of the intermediate point to perform a gradient step.
        [theta_grad_, theta0_grad_] = gradient_theta(N, L, d, time_series, theta, theta0, y_, lambda);
        y_grad_ = gradient_y(N, L, d, time_series, theta_, theta0_, kappa, lambda);

        % Calculate x_i+1.
        theta = theta - rate*(theta_grad_);
        theta0 = theta0 - rate*(theta0_grad_);
        % Project onto the simplex.
        y = projsplx(y + rate*(y_grad_));
        theta(theta>-0.001 & theta<0.001) = 0;

        [err, dist] = prediction(time_series((N-d)+1:N,:), time_series(N+1,:), L, true_theta, theta, true_theta0, theta0);
        % Total Neg. Log Loss.
        log_loss_error(i) = neg_log_loss(N, L, d, time_series, theta, theta0);
        % Prediction error over the time horizon.
        estimation_error(i) = dist;
        % Error of estimation of the parameter vector of the process.
        prediction_error(i) = err;

        i = i + 1;
    end
    figure('visible','on');
    hold on;
    plot(log_loss_error);
    plot(estimation_error);
    plot(prediction_error);
    title('Error');
    xlabel('Iteration');
    ylabel('Error');
    legend('Negative Log Loss','Estimation error', 'Prediction error');
    hold off;
end

% Gradient of the objective w.r.t. the parameter vector x of the process.
function res = F_kappa(N, L, d, time_series, theta, theta0, y, kappa, lambda)
    res = y(2) * (sum(sum(theta))) + y(1) * ((neg_log_loss(N, L, d, time_series, theta, theta0) + lambda * l1_norm(theta)) - kappa);
end

% Gradient of the objective w.r.t. the parameter vector x of the process.
function [theta_grad, theta0_grad] = gradient_theta(N, L, d, time_series, theta, theta0, y, lambda)
    [theta_grad, theta0_grad] = log_loss_gradient(N, L, d, time_series, theta, theta0);
    theta_grad = (theta_grad + lambda*l1_norm_subgrad(theta, L, d*L))*y(1) + y(2);
    theta0_grad = (theta0_grad + lambda*l1_norm_subgrad(theta0, 1, L))*y(1) + y(2);
end

function l1_subgrad = l1_norm_subgrad(x, rows, cols)
    l1_subgrad = zeros(rows, cols);
    for i = 1:rows
        for j = 1:cols
            if x(i,j) > 0
                l1_subgrad(i,j) = 1;
            elseif x(i,j) < 0
                l1_subgrad(i, j) = -1;
            end
        end
    end
end

% Gradient of the objective w.r.t. the weigth vector y of the obj. f-ion and constraints.
function y_grad = gradient_y(N, L, d, time_series, theta, theta0, kappa, lambda)
    y1_grad = neg_log_loss(N, L, d, time_series, theta, theta0) + lambda * l1_norm(theta) - kappa;
    y2_grad = sum(sum(theta));
    y_grad = [y1_grad, y2_grad];
end

% Gradient descent for time series of 2-D Bernouilli events.
function [theta_grad, theta0_grad] = log_loss_gradient(N, L, d, series, theta, theta0)
    theta_grad = zeros(L,d*L);
    theta0_grad = zeros(1,L);
    % For each time instance in the time horizon from d to N.
    for s = d:(N-1)
        % Take values from the last d time instances.
        X = series((s-d+1):s,:);
        X = reshape(X.',1,[]);
        % For each location in the 2D grid of the current time instance.
        for l = 1:L
            y = series(s+1,l);
            a = theta(l,:);
            b = theta0(l);
            % Update the parameter vector.
            theta_grad(l,:) = theta_grad(l,:) + X.*((-1)/(exp(a*X.'+b) + 1)-y+1);
            theta0_grad(l) = theta0_grad(l) + ((-1)/(exp(a*X.'+b) + 1)-y+1);
        end
    end
    theta_grad = theta_grad./((N-d-1)*L);
    theta0_grad = theta0_grad./((N-d-1)*L);
        
end

% Negative cross-entropy loss.
function obj = neg_log_loss(N, L, d, time_series, theta, theta0)
    obj = 0;
    for s = d:(N-1)
        X = time_series((s-d+1):s,:);
        % TODO: try without the following and with transpose
        X = reshape(X.',1,[]);
        % For each location in the 2-D grid.
        for l = 1:L
            y = time_series(s+1,l);
            a = theta(l,:);
            b = theta0(l);
            % Log-likelihood with L1 penalty.
            obj = obj + (log_sum_exp([0; (dot(X,a)+b)]) - (y*(dot(X,a)+b)));
            %obj = obj + log(1 + exp(X.'*theta+theta0)) - y*(X.'*theta+theta0) / (N*L);
        end
    end
    obj = obj/((N-d)*L);
end

% L1 penalty function.
function res = l1_norm(theta)
    res = sum(sum(abs(theta)));
end

function [rate] = linesearch_stepsize(x_i, y_i, x_i_1, grad_y_i, x2_i, y2_i, x2_i_1, grad_y2_i, rate)
    % Backtrack line search for step size.
    i=0;
    while i<2
        if (rate*np.dot((grad_y_i.T),(y_i-x_i_1)) <= (1/2)*np.power(norm(x_i-x_i_1, 2),2)) && (rate*dot((grad_y2_i.T),(y2_i-x2_i_1)) <= (1/2)*power(norm(x2_i-x2_i_1, 2),2))
            beta = np.sqrt(2);
        else
            beta = 0.5;
        end
        rate = rate * beta;
        i=i+1;
    end
end

% Prediction for time series of 2-D Bernouilli events.
function [err, dist] = prediction(X, y, L, true_theta, theta, true_theta0, theta0)
    X = reshape(X.',1,[]);
    prediction = zeros(1,L);
    % For each location in the 2-D grid.
    for l = 1:L
        prediction(l) = sigmoid(theta0(l) + dot(X, theta(l,:)));
    end
    % Squared error of the prediction.
    err = immse(y, prediction);
    % Squared error btween estimated theta and true theta.
    true_theta = full(true_theta);
    true_theta0 = full(true_theta0);
    true_theta = reshape(true_theta.',1,[]);
    true_theta = [true_theta true_theta0];
    theta = reshape(theta.',1,[]);
    theta = [theta theta0];
    dist = sqrt(sum((true_theta-theta).^2));
end