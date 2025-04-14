% Tests fusion center v3.1 for mode control thrust

% Contact: {wwhoward}@vt.edu Wireless @ VT

% Header: 
clc;clear;close all
addpath(genpath(pwd))

% 
dt = 0.1; 
Targets = targetModel(30); 
Trackers = genTrackers(10);  
FC = fusionCenter(Targets,Trackers); 

for t = 0:100
    [~] = Targets.update(dt); 
    for i = 1:length(Trackers)
        [~] = Trackers{i}.observe(Targets, t*dt); 
    end
    FC.getUpdates(t*dt); 
end

FC.updateTargetClasses(); 