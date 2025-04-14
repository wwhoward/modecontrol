% Compares one network using just radar against a network using mode
% control

% Header: 
clc;clear;close all
addpath(genpath(pwd))
% 
dt = 0.1; 
T = 5; 
nRep = 12; 
nEpochs = 10; 

parfor n = 1:nRep
    display("Rep" + string(n))
    
    % Instance objects (Need to do this here but will be written-over immediately 
    tmpTargets = targetModel(1); 
    tmpTrackers = genTrackers(1);  

    radarFC = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Active'); 
    modeFC = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Bandit'); 
    % modeFC = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Random', 'RandomRadarPercent', 0.8); 
    badFC = fusionCenter(tmpTargets, tmpTrackers, 'ModeControl', 'Random', 'RandomRadarPercent', 0.8); 
    
    for e = 1:nEpochs
        Targets = targetModel(10); 
        [radarTrackers, nTrackers, NodeLocations] = genTrackers(10);  
        modeTrackers = genTrackers(10, 'FixedNumber', nTrackers, 'NodeLocations', NodeLocations); 
        badTrackers = genTrackers(10, 'FixedNumber', nTrackers, 'NodeLocations', NodeLocations); 
        % for i = 1:nTrackers
        %     modeTrackers{i}.UseTrueClasses = true; 
        % end
        % for i = 1:nTrackers
        %     radarTrackers{i}.UseTrueClasses = true; 
        % end

        radarFC.newScene(Targets, radarTrackers); 
        modeFC.newScene(Targets, modeTrackers); 
        badFC.newScene(Targets, badTrackers); 

        for t = 0:dt:T
            Targets.update(dt); 
            for i = 1:length(radarTrackers)
                radarTrackers{i}.observe(Targets, t); 
            end
            radarFC.getUpdates(t); 
            radarFC.selectModes; 
            for i = 1:length(modeTrackers)
                modeTrackers{i}.observe(Targets, t); 
            end
            modeFC.getUpdates(t); 
            modeFC.selectModes; 
            for i = 1:length(badTrackers)
                badTrackers{i}.observe(Targets, t); 
            end
            badFC.getUpdates(t); 
            badFC.selectModes; 
        end

        modeFC.updateTargetClasses(); 

        radarStats{e, n} = radarFC.Stats; 
        modeStats{e, n} = modeFC.Stats; 
        badStats{e, n} = badFC.Stats; 
    end
end

radarMeanStats = AverageStats(radarStats); 
modeMeanStats = AverageStats(modeStats); 
badMeanStats = AverageStats(badStats); 
colors = linspecer(3); 
display_names = {"Active Only", "Mode Control - Initial", "Mode Control - Final", "Random"}; 


figure; 
semilogx(radarMeanStats{"ECDF"}{2,2}, radarMeanStats{"ECDF"}{2,1}, 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
hold on
semilogx(modeMeanStats{"ECDF"}{1,2}, modeMeanStats{"ECDF"}{1,1}, '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
semilogx(modeMeanStats{"ECDF"}{end,2}, modeMeanStats{"ECDF"}{end,1}, 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
semilogx(badMeanStats{"ECDF"}{end,2}, badMeanStats{"ECDF"}{end,1}, 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{4})
legend('Interpreter', 'latex', 'fontsize', 12, 'location', 'best')
xlabel('Meters', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Pr(Error $\leq X$)', 'interpreter', 'latex', 'fontsize', 12)

figure; 
hold on
plot(radarMeanStats{"TimeSteps"}, radarMeanStats{"ModeActivePercent"}(end, :), 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
plot(modeMeanStats{"TimeSteps"}, modeMeanStats{"ModeActivePercent"}(1, :), '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
plot(modeMeanStats{"TimeSteps"}, modeMeanStats{"ModeActivePercent"}(end, :), 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
plot(badMeanStats{"TimeSteps"}, badMeanStats{"ModeActivePercent"}(end, :), 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{4})

xlabel('Time (s)', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Nodes Using Radar', 'interpreter', 'latex', 'fontsize', 12)
legend('interpreter', 'latex', 'fontsize', 12)

figure; 
hold on
plot(radarMeanStats{"TimeSteps"}, movmean(radarMeanStats{"ModeActivePercent"}(end, :), 10), 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
%plot(modeMeanStats{"TimeSteps"}, movmean(modeMeanStats{"ModeActivePercent"}(1, :), 5), '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
plot(modeMeanStats{"TimeSteps"}, movmean(modeMeanStats{"ModeActivePercent"}(end, :), 10), 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
plot(badMeanStats{"TimeSteps"}, movmean(badMeanStats{"ModeActivePercent"}(end, :), 10), 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{4})

xlabel('Time (s)', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Nodes Using Radar', 'interpreter', 'latex', 'fontsize', 12)
legend('interpreter', 'latex', 'fontsize', 12)
grid on

% colors = linspecer(nEpochs); 
% figure; 
% for i = 1:nEpochs
%     semilogx(modeMeanStats{"ECDF"}{i,2}, modeMeanStats{"ECDF"}{i,1}, '--', 'Color', colors(i,:), 'linewidth', 2, 'DisplayName', string(i))
%     hold on
% end
% legend('interpreter', 'latex', 'fontsize', 12)

figure; 
x = 0; 
f = 0; 
epochs = 1:nEpochs - 1; 
% epochs = setdiff([10:14], 6); 
for i = epochs
    x = x + modeMeanStats{"ECDF"}{i,2}; 
    f = f + modeMeanStats{"ECDF"}{i,1}; 
end
f = f / length(epochs); 
semilogx(radarMeanStats{"ECDF"}{end,2}, radarMeanStats{"ECDF"}{end,1}, 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
hold on
semilogx(x, f, '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
semilogx(modeMeanStats{"ECDF"}{end,2}, modeMeanStats{"ECDF"}{end,1}, 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
semilogx(badMeanStats{"ECDF"}{end,2}, badMeanStats{"ECDF"}{end,1}, 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{4})
legend('Interpreter', 'latex', 'fontsize', 12, 'location', 'best')
xlabel('Meters', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Pr(Error $\leq X$)', 'interpreter', 'latex', 'fontsize', 12)
grid on
xlim([1e-2, 1e3])

figure; 
for i = 1:nEpochs
    semilogx(modeMeanStats{"ECDF"}{i, 2}, modeMeanStats{"ECDF"}{i, 1}, 'linewidth', 2)
    hold on
end
grid on
xlim([1e-2, 1e3])

figure; 
plot(1:nEpochs, modeMeanStats{"ClassAccuracy"}(1:end), 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', "Class Formation"); 
hold on
plot(1:nEpochs, modeMeanStats{"trackAssociationAccuracy"}(1:end), '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', 'Class Association'); 
xlim([1,nEpochs])
legend('Interpreter', 'latex', 'fontsize', 12, 'location', 'best')
xlabel('Epochs', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Class Accuracy', 'interpreter', 'latex', 'fontsize', 12)
ylim([0,1])
grid on

figure
hold on
plot(modeMeanStats{"TimeSteps"}, modeMeanStats{"Error"}(end,:))
plot(radarMeanStats{"TimeSteps"}, radarMeanStats{"Error"}(end,:))
plot(badMeanStats{"TimeSteps"}, badMeanStats{"Error"}(end,:))

figure; 
x = 0; 
f = 0; 
epochs = 1:nEpochs - 5; 
 %epochs = setdiff([10:14], 6); 
for i = epochs
    x = x + modeMeanStats{"ECDF"}{i,2}; 
    f = f + modeMeanStats{"ECDF"}{i,1}; 
end
f = f / length(epochs); 
semilogx(radarMeanStats{"SS_ECDF"}{end,2}, radarMeanStats{"SS_ECDF"}{end,1}, 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
hold on
%semilogx(x, f, '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
semilogx(modeMeanStats{"SS_ECDF"}{end,2}, modeMeanStats{"SS_ECDF"}{end,1}, 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
semilogx(badMeanStats{"ECDF"}{end,2}, badMeanStats{"ECDF"}{end,1}, 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{4})
legend('Interpreter', 'latex', 'fontsize', 12, 'location', 'best')
xlabel('Meters', 'interpreter', 'latex', 'fontsize', 12)
ylabel('Pr(Error $\leq X$)', 'interpreter', 'latex', 'fontsize', 12)
grid on
xlim([1e0, 1e1])

figure; 
hold on
plot(radarMeanStats{"TimeSteps"}, movmean(radarMeanStats{"ModeActivePercent"}(end, :), 10), 'Color', colors(1,:), 'linewidth', 2, 'DisplayName', display_names{1})
plot(modeMeanStats{"TimeSteps"}, movmean(modeMeanStats{"ModeActivePercent"}(1, :), 10), '--', 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{2})
plot(modeMeanStats{"TimeSteps"}, movmean(modeMeanStats{"ModeActivePercent"}(end, :), 10), 'Color', colors(2,:), 'linewidth', 2, 'DisplayName', display_names{3})
plot(badMeanStats{"TimeSteps"}, movmean(badMeanStats{"ModeActivePercent"}(end, :), 10), 'Color', colors(3,:), 'linewidth', 2, 'DisplayName', display_names{4})



