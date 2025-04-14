function [trackers] = genTrackers(nTrackers, varargin)
    % GENTRACKERS Convenience function to enable instancing of targetTrackers in parfor loops
    % Written for TTT Journal by W.W.Howard in Spring 2023
    % Version information: 
    % v3.0
    % Contact: {wwhoward}@vt.edu Wireless@VT
    
    trackers = {}; 

    if any(strcmp(varargin, 'FixedNumber')) % covered region
        idx = find(strcmp(varargin, 'FixedNumber')); 
        fixedNumber = varargin{idx+1}; 
    else
        fixedNumber = false; 
    end

    % Draw the actual number of nodes from a Poisson distribution
    if ~fixedNumber
        nTrackers = poissrnd(nTrackers); 
    end
    
    for n = 1:nTrackers
        trackers{n} = targetTracker(n, nTrackers, varargin{:}); 
    end
end