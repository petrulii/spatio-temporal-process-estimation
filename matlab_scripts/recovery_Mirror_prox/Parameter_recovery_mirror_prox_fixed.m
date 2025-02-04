function [] = Parameter_recovery_mirror_prox_fixed()
    % Set the random seed.
    rng(0);
    % Dimensions of 2-D space grid.
    row = 5;
    col = row;
    % Memeory depth.
    d = 2;
    % The length of the time horizon is d*periods+1.
    all_periods = [10 100];% 1000 10000];
    len_periods = length(all_periods);
    % Values used in parameter generation.
    radius = 1;
    values = [-1 -1];
    % Lists for plotting.
    iterations = 5;
    all_N = zeros(1, len_periods);
    error_log_l1 = zeros(iterations,len_periods);
    error_lin_l1 = zeros(iterations,len_periods);
    zer_log_l1 = zeros(iterations,len_periods);
    zer_lin_l1 = zeros(iterations,len_periods);
    theta_norm_log_l1 = zeros(iterations,len_periods);
    theta_norm_lin_l1 = zeros(iterations,len_periods);
    % Mirror-prox hyper-parameters.
    lambda = 0.0005;
    max_iterations = 1500;
    max_iterations_kappa = 10;
    
    [time_series, probabilities, N, L, true_theta, true_theta0] = generate_series(row, col, d, 1000, 'operator', radius, values);
    [theta, theta0] = estimate_parameters(N, L, d, time_series, max_iterations, true_theta, true_theta0, lambda, max_iterations_kappa);
    plot_true_pred_series(L, N, d, true_theta, true_theta0, theta, theta0);
    return;
    
    for i = 1:iterations
        % Regularization hyper-parameter.
        for j = 1:len_periods
            
            fprintf('\n\n\n%s %d %s %d\n\n', 'Iteration:', i, ', period index:', j);
            periods = all_periods(j);
            % Generating Bernouilli time series of N+1 time instances and L locations.
            [time_series, probabilities, N, L, true_theta, true_theta0] = generate_series(row, col, d, periods, 'operator', radius, values);
            all_N(j) = N;
            
            % Maximum likelihood estimation with lasso.
            %[theta, theta0, y, obj] = mirror_prox(N, L, d, time_series, 1, rate, max_iterations, true_theta, true_theta0, lambda);
            [theta, theta0] = estimate_parameters(N, L, d, time_series, max_iterations, true_theta, true_theta0, lambda, max_iterations_kappa);
            % Generate a prediction and compare with groud truth.
            [err_log_l1, z_log_l1, t_n_log_l1] = predict(time_series((N-d)+1:N,:), time_series(N+1,:), L, d, true_theta, theta, true_theta0, theta0, row, col, @sigmoid);
            zer_log_l1(i,j) = z_log_l1;
            error_log_l1(i,j) = err_log_l1;
            theta_norm_log_l1(i,j) = t_n_log_l1;
        end
    end
    
    Parameter_recovery_plot(all_N, zer_log_l1, error_log_l1, theta_norm_log_l1, zer_lin_l1, error_lin_l1, theta_norm_lin_l1, 'N');
end

function [theta, theta0] = estimate_parameters(N, L, d, time_series, max_iterations, true_theta, true_theta0, lambda, max_iterations_kappa)
    kappa = 1;
    theta = ones(L,d*L);
    theta0 = ones(1,L);
    
    % Searching for kappa.
    for i = 1:max_iterations_kappa
        fprintf('%s %d\n', 'Kappa search iteration :', i);
        [theta, theta0, y, obj] = mirror_prox(N, L, d, time_series, kappa, max_iterations, true_theta, true_theta0, lambda);
        % Initial value is feasible.
        if i == 1 && obj <= 0
            fprintf('%s %d\n', 'F(kappa) root found, kappa :', kappa);
            return;
        % Not feasible for given kappa.
        elseif obj > 0
            prev_kappa = kappa;
            kappa = kappa * 2;
            prev_obj = obj;
        % Feasible for given kappa.
        else
            [theta, theta0, kappa] = bisection(prev_kappa, kappa, prev_obj, obj, N, L, d, time_series, max_iterations, true_theta, true_theta0, lambda);
            fprintf('%s %d\n', 'F(kappa) root found, kappa :', kappa);
            return;
        end
    end
    fprintf('%s\n', 'No feasible kappa found, exiting now');
    quit;
end

% Bisection to find the root of the function.
function [theta, theta0, c] = bisection(a, b, f_a, f_b, N, L, d, time_series, max_iterations, true_theta, true_theta0, lambda)
    while 1
        c = (a+b)/2;
        fprintf('%s %d\n', 'a', a);
        fprintf('%s %d\n', 'b', b);
        fprintf('%s %d\n', 'c', c);
        [theta, theta0, y, f_c] = mirror_prox(N, L, d, time_series, c, max_iterations, true_theta, true_theta0, lambda);
        if f_c <= 0 && f_c > -0.5
            break;
        else
            if sign(f_a) ~= sign(f_c)
                b = c;
                f_b = f_c;
            elseif sign(f_b) ~= sign(f_c)
                a = c;
                f_a = f_c;
            end
        end
    end
end

function [theta, theta0, y, obj] = mirror_prox(N, L, d, time_series, kappa, max_iterations, true_theta, true_theta0, lambda)
    % Mirror prox.
    % param N: length of the time horizon of the time series
    % param L: number of locations in the 2D spatial grid
    % param d: memory depth of the process
    % param time_series: time series of the process
    theta = randn(L,d*L);
    theta0 = randn(1,L);
    y = [0 0];

    log_loss_error = zeros(1,max_iterations);
    estimation_error = zeros(1,max_iterations);
    prediction_error = zeros(1,max_iterations);
    i = 1;

    while i <= max_iterations

        fprintf('%s %d\n', 'Iteration :', i);
        fprintf('%s %d\n', 'N :', N);
        fprintf('%s %d\n', 'kappa :', kappa);
        fprintf('%s %d %d\n', 'y0 y1 :', y(1), y(2));
        fprintf('%s %d\n', 'F_0(x) :', neg_log_loss(N, L, d, time_series, theta, theta0) + lambda * l1_norm(theta) - kappa);
        fprintf('%s %d\n', 'F_1(x) :', constraint1(theta));
        obj = F_kappa(N, L, d, time_series, theta, theta0, y, kappa, lambda);
        fprintf('%s %d\n', 'F(kappa) :', obj);
        fprintf('%s %d\n', 'sum(theta) :', sum(sum(theta)));
        fprintf('%s %d\n', 'sum(true_theta) :', sum(sum(true_theta)));
        % Find the learning rate.
        rate = 1;
        fprintf('%s %d\n', 'Learning rate :', rate);
        fprintf('%s \n \t %d %d %d \n \t %d %d %d \n', 'First values of true theta :', true_theta(1,1), true_theta(1,2), true_theta(1,3), true_theta(2,1), true_theta(2,2), true_theta(2,3));
        fprintf('%s \n \t %d %d %d \n \t %d %d %d \n', 'First values of pred. theta :', theta(1,1), theta(1,2), theta(1,3), theta(2,1), theta(2,2), theta(2,3));
        
        % Gradient step to go to an intermediate point.
        [theta_grad, theta0_grad] = gradient_theta(N, L, d, time_series, theta, theta0, y, lambda);
        y_grad = gradient_y(N, L, d, time_series, theta, theta0, kappa, lambda);
        
        % Calculate y_i.
        theta_ = theta - rate*theta_grad;
        theta_ = l1_prox(theta_, L, d*L, lambda);
        theta0_ = theta0 - rate*theta0_grad;
        % Project onto the simplex.
        y_ = projsplx(y + rate*(y_grad));

        % Use the gradient of the intermediate point to perform a gradient step.
        [theta_grad_, theta0_grad_] = gradient_theta(N, L, d, time_series, theta_, theta0_, y_, lambda);
        y_grad_ = gradient_y(N, L, d, time_series, theta_, theta0_, kappa, lambda);

        % Calculate x_i+1.
        theta = theta - rate*theta_grad_;
        theta = l1_prox(theta, L, d*L, lambda);
        theta0 = theta0 - rate*theta0_grad_;
        % Project onto the simplex.
        y = projsplx(y + rate*(y_grad_));
        
        % Stop if the gradient is very small.
        if (l1_norm(theta_grad_) < 0.1)
            break;
        end
        theta(theta>-0.0001 & theta<0.0001) = 0;

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

function [t] = adaptive_rate(N, L, d, time_series, theta, theta0, y, kappa, lambda)
    b = 0.5;
    t = 1;
    f_x_y = F_kappa(N, L, d, time_series, theta, theta0, y, kappa, lambda);
    grad_f_x = gradient_theta(N, L, d, time_series, theta, theta0, y, lambda);
    f_x_new = F_kappa(N, L, d, time_series, theta-grad_f_x, theta0, y, kappa, lambda);
    grad_f_y = gradient_theta(N, L, d, time_series, theta, theta0, y, lambda);
    f_y_new = F_kappa(N, L, d, time_series, theta-grad_f_x, theta0, y, kappa, lambda);
    while f_x_new > f_x_y - rate/2 * (norm(grad_f_x))^2 && f_y_new > f_x_y - rate/2 * (norm(grad_f_y))^2
        t = b*t;
        disp(t);
    end
end

% Prox mapping.
function [x] = prox(N, L, d, time_series, y, kappa, lambda, theta0, theta, theta_grad, rate)
    theta_vec = reshape(theta.',1,[]);
    theta_grad_vec = reshape(theta_grad.',1,[]);
    cvx_begin
        variable x(L, d*L);
        x_vec = reshape(x.',1,[]);
        minimize(dot(rate*theta_grad_vec, x_vec-theta_vec)+berg_divergence(N, L, d, time_series, y, kappa, lambda, theta0, x, x_vec, theta, theta_vec, theta_grad_vec));
    cvx_end
end

function [div] = berg_divergence(N, L, d, time_series, y, kappa, lambda, theta0, p, p_vec, q, q_vec, q_grad)
    f_p = F_kappa(N, L, d, time_series, p, theta0, y, kappa, lambda);
    f_q = F_kappa(N, L, d, time_series, q, theta0, y, kappa, lambda);
    div = f_p - f_q - dot(q_grad, p_vec-q_vec);
end

% Gradient of the objective w.r.t. the parameter vector x of the process.
function res = F_kappa(N, L, d, time_series, theta, theta0, y, kappa, lambda)
    res = y(1) * ((neg_log_loss(N, L, d, time_series, theta, theta0) + lambda * l1_norm(theta)) - kappa) + y(2) * constraint1(theta);
end

% Gradient of the objective w.r.t. the parameter vector x of the process.
function [theta_grad, theta0_grad] = gradient_theta(N, L, d, time_series, theta, theta0, y, lambda)
    % Gradient step of the differentiable log. loss.
    [theta_grad, theta0_grad] = log_loss_gradient(N, L, d, time_series, theta, theta0);
    % Prox operator of the L1 norm.
    theta_grad = (theta_grad)*y(1) + y(2);
    %theta_grad = (theta_grad + l1_prox(theta, L, d*L, lambda))*y(1) + y(2);
    theta0_grad = theta0_grad + y(2);
end

% Proximal operator of the L1 norm.
function x = l1_prox(x, rows, cols, lambda)
    for i = 1:rows
        for j = 1:cols
            if x(i,j) >= lambda
                x(i,j) = x(i,j) - lambda;
            elseif x(i,j) <= -1*lambda
                x(i,j) = x(i,j) + lambda;
            end
        end
    end
end

% Gradient of the objective w.r.t. the weigth vector y of the obj. f-ion and constraints.
function y_grad = gradient_y(N, L, d, time_series, theta, theta0, kappa, lambda)
    y1_grad = neg_log_loss(N, L, d, time_series, theta, theta0) + lambda * l1_norm(theta) - kappa;
    y2_grad = constraint1(theta);
    y_grad = [y1_grad, y2_grad];
end

% Gradient of the log-loss function for time series of 2-D Bernouilli events.
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
            p = sigmoid(a*X.'+b);
            theta_grad(l,:) = theta_grad(l,:) + X.*((-1)/(exp(a*X.'+b) + 1)-y+1);%X.*(p-y);%X.*((-1)/(exp(a*X.'+b) + 1)-y+1);
            theta0_grad(l) = theta0_grad(l) + ((-1)/(exp(a*X.'+b) + 1)-y+1);%(p-y);%((-1)/(exp(a*X.'+b) + 1)-y+1);
        end
    end
    theta_grad = theta_grad./((N-d)*L);
    theta0_grad = theta0_grad./((N-d)*L);
end

% Negative cross-entropy loss.
function obj = neg_log_loss(N, L, d, time_series, theta, theta0)
    obj = 0;
    for s = d:(N-1)
        X = time_series((s-d+1):s,:);
        X = reshape(X.',1,[]);
        % For each location in the 2-D grid.
        for l = 1:L
            y = time_series(s+1,l);
            a = theta(l,:);
            b = theta0(l);
            % Log-likelihood with L1 penalty.
            obj = obj + (log_sum_exp([0; (dot(X,a)+b)]) - (y*(dot(X,a)+b)));
        end
    end
    obj = obj/((N-d)*L);
end

% L1 penalty function.
function res = l1_norm(theta)
    res = sum(sum(abs(theta)));
end

function f1 = constraint1(theta)
    f1 = sum(sum(theta));
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