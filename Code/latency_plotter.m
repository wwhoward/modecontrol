% Plot latency figure

% Get 0s latency
fig1 = open('figs/30oct/ecdf.fig'); 
a1 = get(gca, 'Children'); 
xdata1 = get(a1, 'XData'); 
ydata1 = get(a1, 'YData'); 
close all

fig2 = open('figs/latency.fig'); 
a2 = get(gca, 'Children'); 
xdata2 = get(a2(2:4), 'XData'); 
ydata2 = get(a2(2:4), 'YData'); 
close all

colors = linspecer(4); 
colors = colors([3, 4, 1, 2], :); % Sort colors appropriately
display_names = {"$\sigma_L = 0$", "$1$", "$3$", "$10$"}; 
linspcs = {'-', '--', '-.', ':'}; 


figure
semilogx(xdata1{4}, ydata1{4}, linspcs{1}, 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
hold on
semilogx(xdata2{2}, ydata2{2}, linspcs{3}, 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{2})
semilogx(xdata2{1}, ydata2{1}, linspcs{2}, 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
grid on
xlim([5e-1, 1e2])
xlabel('Meters', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Pr(Error $\leq X$)', 'interpreter', 'latex', 'fontsize', 12)
legend('Location', 'Best', 'interpreter', 'latex', 'fontsize', 12)

