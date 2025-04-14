function [averageStats] = AverageStats(stats)
%AVERAGESTATS Written for TTT Journal by W.W.Howard in Spring 2023
% Version information: 
% For TimelyTrackingNetwork v3.0
% Contact: {wwhoward}@vt.edu

% Input: 
% Stats -> (nParam by nRep)

% Output: 
% averageStats -> stats, averaged over the nRep dimension

averageStats = dictionary(); 
nParams = size(stats, 1); 
nRep = size(stats, 2); 


% Get initial TimeSteps for comparison
baseTimeSteps = stats{1,1}{"TimeSteps"}; 
nSteps = length(baseTimeSteps); 

age = zeros(nParams, nRep, nSteps); 
peak_age = zeros(nParams, nRep, nSteps); 
err = zeros(nParams, nRep, nSteps);
rmse  = zeros(nParams, nRep, nSteps);
covered  = zeros(nParams, nRep, nSteps);
tracked  = zeros(nParams, nRep, nSteps);
total = zeros(nParams, nRep, nSteps); 
active = zeros(nParams, nRep, nSteps); 
selected = zeros(nParams, nRep, nSteps); 
selection_entropy = zeros(nParams, nRep); 
selected_targets = zeros(nParams, nRep, nSteps); 
maneuv_vs_rate = {}; 


for p = 1:nParams
    maneuv_vs_rate{p} = []; 
    for n = 1:nRep
        if any(stats{p, n}{"TimeSteps"} ~= baseTimeSteps)
            error("Can't synchronize time steps... ")
        end
        age(p, n, :) = stats{p, n}{"Age"}; 
        peak_age(p, n, :) = stats{p, n}{"PeakAge"}; 
        err(p, n, :) = stats{p, n}{"Error"}; 
        rmse(p, n, :) = stats{p, n}{"RMSE"}; 
        covered(p, n, :) = stats{p, n}{"nCoveredTargets"}; 
        tracked(p, n, :) = stats{p, n}{"nTrackedTargets"}; 
        total(p, n, :) = stats{p, n}{"nTotalTargets"}; 
        active(p, n, :) = stats{p,n}{"nActiveTargets"}; 
        selected(p, n, :) = stats{p,n}{"nSelectedNodes"}; 
        selected_targets(p, n, :) = stats{p,n}{"nObservedTargets"}; 

        % map average update rate (i.e., # updates / target age) to manuv
        manu = stats{p,n}{"TransitionEntropy"}; % has /all/ targets
        dur = stats{p,n}{"TargetAge"}; 
        dur = cell2mat(dur); 
        dur(dur==0) = 1; 
        tmp = cell2mat(stats{p,n}{"ObservedTargets"}');
        [c, u] = hist(tmp, unique(tmp)); 

        rate = c ./ dur(u); % Only observed targets
        manu = cell2mat(manu(u)); 
        maneuv_vs_rate{p} = [maneuv_vs_rate{p}, [rate; manu]]; 
        

        tmp = stats{p,n}{"SelectionCounts"} / sum(stats{p,n}{"SelectionCounts"}); 
        selection_entropy(p, n) = -sum(tmp(tmp>0).*log2(tmp(tmp>0)))/length(tmp); 
    end % end for nRep
end % end for nParams

if max(baseTimeSteps)<5
    error('Needs at least 5s of data for averaging')
end

tmp_error = reshape(err, nParams, nRep*nSteps); 
[~, SS_idx] = find((baseTimeSteps-5)>=0); 
[~, early_idx] = find(baseTimeSteps<5); 
SS_error = reshape(err(:, :, SS_idx(1):end), nParams, nRep*length(SS_idx)); 
early_error = reshape(err(:,:,1:early_idx(end)), nParams, nRep*length(early_idx)); 
for p = 1:nParams
    [averageStats{"ECDF"}{p, 1}, averageStats{"ECDF"}{p, 2}] = ecdf(tmp_error(p, :)); 
    [averageStats{"SS_ECDF"}{p, 1}, averageStats{"SS_ECDF"}{p, 2}] = ecdf(SS_error(p, :)); 
    [averageStats{"early_ECDF"}{p, 1}, averageStats{"early_ECDF"}{p, 2}] = ecdf(early_error(p, :)); 
end

averageStats{"TimeSteps"} = baseTimeSteps; 

averageStats{"Age"} = squeeze(mean(age, 2)); 
averageStats{"PeakAge"} = squeeze(mean(peak_age, 2)); 
averageStats{"Error"} = squeeze(mean(err, 2)); 
averageStats{"RMSE"} = squeeze(mean(rmse, 2)); 
averageStats{"nCoveredTargets"} = squeeze(mean(covered, 2)); 
averageStats{"nTrackedTargets"} = squeeze(mean(tracked, 2)); 
averageStats{"nTotalTargets"} = squeeze(mean(total, 2)); 
averageStats{"nActiveTargets"} = squeeze(mean(active, 2)); 
averageStats{"nSelectedNodes"} = squeeze(mean(selected, 2)); 
averageStats{"SelectionEntropy"} = squeeze(mean(selection_entropy, 2)); 
averageStats{"nSelectedTargets"} = squeeze(mean(selected_targets, 2)); 
averageStats{"ManeuvVsRate"} = maneuv_vs_rate; 


% Notes
% Need age, peak age, error, rmse, covered t, tracked t, total t, selected n 




end

