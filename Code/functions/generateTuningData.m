% Generates a bunch of data that can be used to tune Kalman filters
% Written for Mode Control Journal in Summer 2023
% For use with Timely Target Tracking network v3.1
% 
% @author {wwhoward}@vt.edu Wireless @ VT
clc;clear;close all
addpath(genpath(pwd))

% Time step
dt = 0.2; 

% number trackers
nTrackers = 10; 
% number targets
nTargets = 10; 
% number time steps
nTimeSteps = 20; 


%% Generate data
[Class1_Truth, Class1_Dets] = generateData(nTrackers, nTargets, nTimeSteps, dt, 1); 
[Class2_Truth, Class2_Dets] = generateData(nTrackers, nTargets, nTimeSteps, dt, 2); 
[Class3_Truth, Class3_Dets] = generateData(nTrackers, nTargets, nTimeSteps, dt, 3); 


%% Now tune the filters
[Class1_Tuner, Class1_props] = tuneFilterOnData(Class1_Truth, Class1_Dets); 
save('tuned_filters/Class1_props.mat', 'Class1_props'); 

[Class2_Tuner, Class2_props] = tuneFilterOnData(Class2_Truth, Class2_Dets); 
save('tuned_filters/Class2_props.mat', 'Class2_props'); 

[Class3_Tuner, Class3_props] = tuneFilterOnData(Class3_Truth, Class3_Dets); 
save('tuned_filters/Class3_props.mat', 'Class3_props'); 


%% Function definitions

function [tunedFilter, tunedProps] = tuneFilterOnData(truth, detlog)
    disp('Tuning Filter, start time: ' + string(datetime))
    tuner = trackingFilterTuner(FilterInitializationFcn="initekfimm",...
                                Solver = "fmincon", ...
                                UseParallel=true); 
    tuner.SolverOptions = optimoptions("fmincon",MaxIterations=60);

    tunedFilter = feval(tuner.FilterInitializationFcn, detlog{1}{1}); 
    
    tunedProps = tune(tuner, detlog, truth);

    setTunedProperties(tunedFilter, tunedProps);      
end % end function tuneFilterOnData

function [truth, detections] = generateData(nTrackers, nTargets, nTimeSteps, dt, class)
    % Init tracking network with wide observation region
    % should cover 1000% of the region
    Trackers = genTrackers(nTrackers, ...
                           'Coverage', 10, ...
                           'FixedNumber', 10, ...
                           'FilterType', 'untuned'); 
    nTrackers = length(Trackers); 
    targetClassProbabilities = circshift([1,0,0], class-1); 
    
    % Spawn target class 1 (SUV)
    Targets = targetModel(nTargets, 'targetClassProbabilities', targetClassProbabilities, 'pRetire', 0); 
    disp('Spawning Class '+string(class))
    
    for i = 1:nTimeSteps % Iterate motion models, 20s of data
        [~] = Targets.update(dt); 
        for j = 1:nTrackers
            [~] = Trackers{j}.observe(Targets, i*dt);
        end
    end

    disp('Extracting data Class '+string(class)) 
    
    % Extract detections & truth
    for j = 1:nTrackers
        tmp_detections{j} = Trackers{j}.getDetections('all'); 
    end
    
    % For each target... 
    for t = 1:nTargets
        tmp_detLog = num2cell(zeros(nTimeSteps, nTrackers)); 
        for j = 1:nTrackers
            for i = 1:nTimeSteps
                tmp_detLog{i,j} = tmp_detections{j}{t}{i}; 
            end
        end
        detections{t} = tmp_detLog; 
        truth{t} = timetable(seconds(Targets.Targets{t}.updateTimes(2:end))', ...
                                    Targets.Targets{t}.Track(1:2:end, 2:end)', ...
                                    Targets.Targets{t}.Track(2:2:end, 2:end)', ...
                                    'VariableNames', ["Position", "Velocity"]); 
    end % end for nTargets
end % end function getData