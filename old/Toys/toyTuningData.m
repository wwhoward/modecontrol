% Uses single node observation of targets to determine if tuned filter
% works better than untuned

clc;clear;close all
addpath(genpath(pwd))

% Number of targets
nTargets = 10; 
% Number of nodes
nTrackers = 1; 
% Number of time steps
nTimeSteps = 100; 
% Size of time step
dt = 0.1; 

% Desired target class
targetClass = 3; 
targetClassProbabilities = circshift([1,0,0], targetClass-1); 

Targets = targetModel(nTargets, 'pRetire', 0, 'targetClassProbabilities', targetClassProbabilities); 

% Ensure trackers can see everything & that there's just one
% Use untuned filter
baseTrackers = genTrackers(nTrackers, ...
                           'Coverage', 10, ...
                           'FixedNumber', true, ...
                           'NodePosition', [5000, 5000], ...
                           'FilterType', 'untuned'); 
% use tuned filter
Class1_Trackers = genTrackers(nTrackers, ...
                           'Coverage', 10, ...
                           'FixedNumber', true, ...
                           'NodePosition', [5000, 5000], ...
                           'FilterType', 'tuned', ...
                           'TargetClass', 1); 

% use tuned filter
Class2_Trackers = genTrackers(nTrackers, ...
                           'Coverage', 10, ...
                           'FixedNumber', true, ...
                           'NodePosition', [5000, 5000], ...
                           'FilterType', 'tuned', ...
                           'TargetClass', 2); 

% use tuned filter
Class3_Trackers = genTrackers(nTrackers, ...
                           'Coverage', 10, ...
                           'FixedNumber', true, ...
                           'NodePosition', [5000, 5000], ...
                           'FilterType', 'tuned', ...
                           'TargetClass', 3); 


for t = 1:nTimeSteps
    w = waitbar(t/nTimeSteps); 
    [~] = Targets.update(dt); 
    for n = 1:nTrackers
        [~] = baseTrackers{n}.observe(Targets, t*dt); 
        [~] = Class1_Trackers{n}.observe(Targets, t*dt); 
        [~] = Class2_Trackers{n}.observe(Targets, t*dt); 
        [~] = Class3_Trackers{n}.observe(Targets, t*dt); 
    end
end
close(w)

% Determine error
err_base = zeros(nTargets, nTimeSteps); 
err_Class1 = zeros(nTargets, nTimeSteps); 
err_Class2 = zeros(nTargets, nTimeSteps); 
err_Class3 = zeros(nTargets, nTimeSteps); 
for m = 1:nTargets
    tru = Targets.Targets{m}.Track(1:2:end, 3:end); 
    est_base = baseTrackers{1}.Targets{m}.FilteredTrack(1:2:end, :); 
    est_Class1 = Class1_Trackers{1}.Targets{m}.FilteredTrack(1:2:end, :); 
    est_Class2 = Class2_Trackers{1}.Targets{m}.FilteredTrack(1:2:end, :); 
    est_Class3 = Class3_Trackers{1}.Targets{m}.FilteredTrack(1:2:end, :); 

    err_base(m,:) = vecnorm(tru-est_base); 
    err_Class1(m,:) = vecnorm(tru-est_Class1); 
    err_Class2(m,:) = vecnorm(tru-est_Class2); 
    err_Class3(m,:) = vecnorm(tru-est_Class3); 
end

figure; 
semilogy(mean(err_base, 1), 'linewidth', 2, 'DisplayName', 'Untuned Filter')
hold on
semilogy(mean(err_Class1, 1), 'linewidth', 2, 'DisplayName', 'Class 1 Filter')
semilogy(mean(err_Class2, 1), 'linewidth', 2, 'DisplayName', 'Class 2 Filter')
semilogy(mean(err_Class3, 1), 'linewidth', 2, 'DisplayName', 'Class 3 Filter')
legend('interpreter', 'latex', 'fontsize', 12, 'location', 'best')
title('Class ' + string(targetClass) + ' Target Error', 'interpreter', 'latex', 'fontsize', 16)




