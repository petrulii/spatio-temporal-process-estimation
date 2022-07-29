function [] = plot_series(series,n,row,col)
    f = figure('visible','on');
    % Plotting the first plot
    for t = 1:n
        subplot(6,20,t);
        colormap(flipud(hot));
        grid = reshape(series(t,:),row,col)';
        imagesc(grid);
        set(gca,'xtick',[],'ytick',[])
        shading interp;
    end
    colorbar;
    saveas(f, 'series_heatmaps', 'png');
end