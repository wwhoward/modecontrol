% Simple proof-of-concept for Mode Control paper
% 

% Function: Spawn target class 1 (SUV)
Class1_Targets = targetModel(100, 'targetClassProbabilities', [1,0,0]); 
disp('Spawning Class 1')
for i = 1:200 % Iterate motion models, 20s of data
    Class1_Targets.update(0.1); 
end


% Function: Spawn target class 2 (UAV)
Class2_Targets = targetModel(100, 'targetClassProbabilities', [0,1,0]); 
disp('Spawning Class 2')
for i = 1:200 % Iterate motion models, 20s of data
    Class2_Targets.update(0.1); 
end


% Function: Spawn target class 3 (AIR)
disp('Spawning Class 3')
Class3_Targets = targetModel(100, 'targetClassProbabilities', [0,0,1]); 
for i = 1:200 % Iterate motion models, 20s of data
    Class3_Targets.update(0.1); 
end

tuner = trackingFilterTuner(FilterInitializationFcn="initekfimm",...
                            UseMex=true, ...
                            UseParallel=true); 




% 