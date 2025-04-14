% Demos meta-learning using FC to maintain class info

% Contact: {wwhoward}@vt.edu Wireless @ VT

% Header: 
clc;clear;close all
addpath(genpath(pwd))
% 
dt = 0.5; 
Targets = targetModel(50); 
Trackers = genTrackers(10);  
FC = fusionCenter(Targets,Trackers); 

for t = 0:50
    [~] = Targets.update(dt); 
    for i = 1:length(Trackers)
        [~] = Trackers{i}.observe(Targets, t*dt); 
    end
    FC.getUpdates(t*dt); 
    FC.selectModes(); 
end

stats = FC.Stats; 
figure
plot(stats{"TimeSteps"}, stats{"Error"})

meanstats1 = AverageStats({stats}); 


% Form classes
FC.updateTargetClasses(); 

% Instance new targets & trackers
Targets = targetModel(50); 
Trackers = genTrackers(10);  

% Clear FC track memory
FC.newScene(Targets, Trackers); 

for t = 0:50
    [~] = Targets.update(dt); 
    for i = 1:length(Trackers)
        [~] = Trackers{i}.observe(Targets, t*dt); 
    end
    FC.getUpdates(t*dt); 
    FC.selectModes(); 
end

FC.updateTargetClasses(); 

stats = FC.Stats; 
figure
plot(stats{"TimeSteps"}, stats{"Error"})

meanstats2 = AverageStats({stats}); 

% Update classes
FC.updateTargetClasses(); 

figure
semilogx(meanstats1{"ECDF"}{2}, meanstats1{"ECDF"}{1}, 'linewidth', 2, 'displayname', 'Epoch 1')
hold on
semilogx(meanstats2{"ECDF"}{2}, meanstats2{"ECDF"}{1}, 'linewidth', 2, 'displayname', 'Epoch 2')
legend('fontsize', 12, 'interpreter', 'latex')

