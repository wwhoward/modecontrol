% Examine effect of network latency

% Header: 
clc;clear;close all
addpath(genpath(pwd))
% 
dt = 0.05; 
T = 5; 
nRep = 2; 
nEpochs = 10; 

parfor n = 1:nRep
    display("Rep" + string(n))

    % Instance objects
    tmpTargets = targetModel(1); 
    tmpTrackers = genTrackers(1); 

    FC_0 = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Bandit', 'pTX', 0); 
    FC_1 = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Bandit', 'pTX', 1); 
    FC_3 = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Bandit', 'pTX', 3); 
    FC_10 = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Bandit', 'pTX', 10); 

    for e = 1:nEpochs
        Targets = targetModel(10); 

        [trackers_0, nTrackers, nodeLocations] = genTrackers(10); 
        
        trackers_1 = genTrackers(10, 'FixedNumber', nTrackers, 'NodeLocations', nodeLocations); 
        trackers_3 = genTrackers(10, 'FixedNumber', nTrackers, 'NodeLocations', nodeLocations); 
        trackers_10 = genTrackers(10, 'FixedNumber', nTrackers, 'NodeLocations', nodeLocations); 

        FC_0.newScene(Targets, trackers_0); 
        FC_1.newScene(Targets, trackers_1); 
        FC_3.newScene(Targets, trackers_3); 
        FC_10.newScene(Targets, trackers_10); 

        for t = 0:dt:T
            Targets.update(dt); 
            for i = 1:nTrackers
                trackers_0{i}.observe(Targets, t); 
                trackers_1{i}.observe(Targets, t); 
                trackers_3{i}.observe(Targets, t); 
                trackers_10{i}.observe(Targets, t); 
            end

            FC_0.getUpdates(t); 
            FC_1.getUpdates(t); 
            FC_3.getUpdates(t); 
            FC_10.getUpdates(t); 

            FC_0.selectModes; 
            FC_1.selectModes; 
            FC_3.selectModes; 
            FC_10.selectModes; 
        end

        FC_0.updateTargetClasses(); 
        FC_1.updateTargetClasses(); 
        FC_3.updateTargetClasses(); 
        FC_10.updateTargetClasses(); 

        stats_0{e, n} = FC_0.Stats; 
        stats_1{e, n} = FC_1.Stats; 
        stats_3{e, n} = FC_3.Stats; 
        stats_10{e, n} = FC_10.Stats; 
    end
end

mean_0 = AverageStats(stats_0); 
mean_1 = AverageStats(stats_1); 
mean_3 = AverageStats(stats_3); 
mean_10 = AverageStats(stats_10); 

colors = linspecer(4); 
colors = colors([3, 4, 1, 2], :); % Sort colors appropriately
display_names = {"$\sigma_L = 0$", "$1$", "$3$", "$10$"}; 
linspcs = {'-', '--', '-.', ':'}; 



figure
semilogx(mean_0{"SS_ECDF"}{end,2}, mean_0{"SS_ECDF"}{end,1}, linspcs{1}, 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
hold on
semilogx(mean_1{"SS_ECDF"}{end,2}, mean_1{"SS_ECDF"}{end,1}, linspcs{2}, 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
semilogx(mean_3{"SS_ECDF"}{end,2}, mean_3{"SS_ECDF"}{end,1}, linspcs{3}, 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{3})
% semilogx(mean_10{"SS_ECDF"}{end,2}, mean_10{"SS_ECDF"}{end,1}, linspcs{4}, 'Color', colors(4,:), 'linewidth', 2, 'DisplayName', display_names{4})
xlabel('Meters', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Pr(Error $\leq X$)', 'interpreter', 'latex', 'fontsize', 12)
grid on
% xlim([5e-1, 1e1])
legend('Location', 'Best', 'interpreter', 'latex', 'fontsize', 12)











