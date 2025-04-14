clc;clear;close all
% Using matlab's trackerPHD system object

% Init sensor config
config = trackingSensorConfiguration(1); 
config.ClutterDensity = 1e-7; 
config.IsValidTime = true; 

% Create the tracker
tracker = trackerPHD('SensorConfigurations', config); 

% Create detections and update tracker
detections = cell(20, 1); 
for i = 1:10
    detections{i} = objectDetection(0, [5;-5;0] + 0.2*randn(3,1)); 
end
for j = 11:20
    detections{j} = objectDetection(0, [-5;5;0] + 0.2*randn(3,1)); 
end

tracker(detections, 0); % Update

% Update again after 0.1s assume targets velocity [1;2;0]/s

dT = 0.1; 
for i = 1:20
    detections{i}.Time = detections{i}.Time + dT; 
    detections{i}.Measurement = detections{i}.Measurement + [1;2;0]*dT; 
end

[confTracks, tentTracks, allTracks] = tracker(detections, dT); 

% Viz dets and confirmed tracks
% Obtain measurements from detections
d = [detections{:}]; 
measurements = [d.Measurement]; 

% Extract positions of configmed tracks using getTrackPositions
% Note default sensor config
% FilterInitializationFcn, initcvggiwphd, which uses cv filter and defines
% states as [x;vx;y;vy;z;vz]
positionSelector = [1 0 0 0 0 0;0 0 1 0 0 0;0 0 0 0 1 0];
positions = getTrackPositions(confTracks, positionSelector); 

figure()
plot(measurements(1,:),measurements(2,:),'x','MarkerSize',5,'MarkerEdgeColor','b');
hold on;
plot(positions(1,1),positions(1,2),'v','MarkerSize',5,'MarkerEdgeColor','r' );
hold on;
plot(positions(2,1),positions(2,2),'^','MarkerSize',5,'MarkerEdgeColor','r' );
legend('Detections','Track 1','Track 2')
xlabel('x')
ylabel('y')


%% Attempt at IMM PHD filter

% Create detections 
detections = cell(20, 1); 
for i = 1:10
    detections{i} = objectDetection(0, [5;-5;0] + 0.2*randn(3,1)); 
end
for j = 11:20
    detections{j} = objectDetection(0, [-5;5;0] + 0.2*randn(3,1)); 
end

filter1 = initcvgmphd(detections); 
filter2 = initcagmphd(detections); 
filter3 = initctgmphd(detections); 

filters = {filter1, filter2, filter3}; 

imm = trackingIMM(filters); 