% Verify that as t \to \infty or as M \to \infty, emperical motion model
% converges to the intended. 

clc;clear;close all
dt = 0.1; 
T=500; 
nRep = 10; 

% First, let t \to \infty for /one/ target
class = 3; 
distance = zeros(1, nRep); 
for i = 1:nRep
    i
    myTarget = targetModel(1, 'targetClassProbabilities', circshift([1,0,0], class-1), 'pRetire', 0); % One target of class 1 that does not quit
    
    mm = []; 
    for t = 0:dt:T
        [~] = myTarget.update(dt); 
        mm(end+1) = myTarget.Targets{1}.motion; 
    end
    
    measured_model_probs = zeros(1,3); 
    for j = 1:3
        measured_model_probs(j) = sum(mm==j)/length(mm); 
    end
    true_model_probs = myTarget.Targets{1}.Class.model_probs; 
    
    distance(i) = vecnorm(abs(measured_model_probs - true_model_probs)); 
    
    % myTarget.plotTrackProjection(myTarget.Targets{1})

end
mean(distance) % Ideally close to zero

%% 
dt = 0.1; 
T = 50; 
nRep = 100; 
class = 3; 
distance = zeros(1, nRep); 
for i = 1:nRep
    i
    myTarget = targetModel(1, 'targetClassProbabilities', circshift([1,0,0], class-1), 'pRetire', 0);
    mm = []; 
    for t = 0:dt:T
        [~] = myTarget.update(dt); 
        mm(end+1) = myTarget.Targets{1}.motion; 
    end
    measured_model_probs = zeros(1,3); 
    for j = 1:3
        measured_model_probs(j) = sum(mm==j)/length(mm); 
    end
    true_model_probs = myTarget.Targets{1}.Class.model_probs; 
    
    distance(i) = vecnorm(abs(measured_model_probs - true_model_probs)); 
end
mean(distance) % Ideally close to zero
