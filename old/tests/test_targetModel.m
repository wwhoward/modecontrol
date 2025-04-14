% Test script for TimelyTrackingNetworkv3.1 targetModel
clc;clear;close all

for i = 1:100 % Do it a few times to ensure no weirdness
    myTargets = targetModel(10); 
end

for i = 1:100 % Iterate motion models
    myTargets.update(0.1); 
end

myTargets.plotTrack(myTargets.Targets{1})