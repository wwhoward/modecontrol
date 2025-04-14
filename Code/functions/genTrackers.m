function [trackers, nTrackers, NodeLocations] = genTrackers(nTrackers, varargin)
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
    else
        nTrackers = fixedNumber; 
    end

    if any(strcmp(varargin, 'NodeLocations')) % preferred placements
        idx = find(strcmp(varargin, 'NodeLocations')); 
        preferredLocation = true; 
        NodeLocations = varargin{idx+1}; 
    else
        preferredLocation = false; 
        NodeLocations = zeros(2, nTrackers);  
    end


    
    
    
    for n = 1:nTrackers
        if preferredLocation
            tmp_varargin = varargin; 
            tmp_varargin{end+1} = 'NodePosition';  
            tmp_varargin{end+1} = NodeLocations(:, n); 
            trackers{n} = targetTracker(n, nTrackers, tmp_varargin{:}); 
        else
            trackers{n} = targetTracker(n, nTrackers, varargin{:}); 
            NodeLocations(:, n) = trackers{n}.NodePosition; 
        end
    end

end