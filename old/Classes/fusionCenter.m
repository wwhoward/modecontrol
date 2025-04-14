classdef fusionCenter < handle
    %FUSIONCENTER Written for TTT Journal by W.W.Howard in Spring 2023
    %   Functions as a fusion center, combining observations from several
    %   'targetTracker' objects tracking 'targetModel'. 
    % 
    % Version information: 
    %   v3.1 8/8/23
    % 
    % Primarily for the study of Age of Information metrics as applied to
    % Cognitive Radar Networks. 

    % Also built with mode control in mind... 
    % 
    % Contact: {wwhoward}@vt.edu

    properties
        Targets
        updateChannels

        ActiveTargets = []
        Stats = dictionary(); 

        % Switches
        doStatistics = true % Should error, etc, be calculated? 

        % Version
        version = '3.1'
    end % end public properties

    properties(Access=private)
        Capacity
        updateRate
        Bandit
        targetModel
        targetTrackers
        selectNodes
        selectionCounts
        activeTargetsSeenByNodes = {}
        activeTargetsNotSeenByNodes = {} % Node has been pulled AND target is seen somewhere but didn't see this target
        activeNodesSeenByTargets = {}
        nTrackers
        NodePositions
        Time = 0
        update_times = [0]
        updated_nodes = {}; 
        updated_targets = {}; 
    end % end private properties
    
    methods(Access=public)
        function obj = fusionCenter(targetModel, targetTrackers, decisionType, updateRate)
            %FUSIONCENTER fuses measurements from targetTracker, works with targetModel 
            % Required inputs: 
                % targetModel: model of target behavior
                % targetTrackers: objects which do the tracking
                % decisionType: How the FC collects observations
                % updateRate: how often each node can provide updates
            
            obj.targetModel = targetModel; 
            obj.targetTrackers = targetTrackers; 
            obj.updateRate = updateRate; 

            obj.nTrackers = length(targetTrackers); 
            obj.selectionCounts = zeros([1, obj.nTrackers]); 
            
            switch decisionType
                case 'all'
                    obj.selectNodes = @obj.getAllUpdates; 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('centralized'); 
                    end % end for
                case 'timely'
                    obj.selectNodes = @obj.getTimelyUpdates; 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('centralized'); 
                    end % end for
                case 'distributed'
                    obj.selectNodes = @obj.getDistributedUpdates; 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('distributed'); 
                    end % end for
                case 'bandit'
                    obj.selectNodes = @obj.getBanditUpdates; 
                    obj.Bandit = UCB(obj.nTrackers, 1, 1, 'n_selections', obj.nTrackers); 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('centralized'); 
                    end % end for
                case 'centralized_random'
                    obj.selectNodes = @obj.getCentralizedRandomUpdates; 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('centralized'); 
                    end % end for
                case 'distributed_random'
                    obj.selectNodes = @obj.getDistributedRandomUpdates;
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod(decisionType); 
                    end % end for
                case 'round_robin'
                    obj.selectNodes = @obj.getRoundRobinUpdates; 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('centralized')
                    end % end for 

                case 'tmp_distributed'
                    obj.selectNodes = @obj.getTmpDistributedUpdates; 
                    for i = 1:obj.nTrackers
                        obj.targetTrackers{i}.addUpdateMethod('tmp_distributed'); 
                    end % end for
            end % end switch
            
            % Initialize trackers
            for n_tracker = 1:length(obj.targetTrackers)
                % Get updateChannel from trackers 
                obj.updateChannels{n_tracker} = obj.targetTrackers{n_tracker}.updateChannels; 

                % Populate activeTrackerTargets, keeps record of who sees who 
                obj.activeTargetsSeenByNodes{n_tracker} = []; 
                obj.activeTargetsNotSeenByNodes{n_tracker} = []; 

                % Register where our nodes live
                obj.NodePositions(:, n_tracker) = obj.targetTrackers{n_tracker}.NodePosition; 
            end % end for

            if obj.doStatistics
                obj.Stats("TimeSteps") = {[]}; % for plotting
                obj.Stats("Error") = {[]}; % Pstates error for tracked targets
                obj.Stats("RMSE") = {[]}; % Root mean squared error for tracked targets
                obj.Stats("Age") = {[]}; % Average age of tracked targets 
                obj.Stats("PeakAge") = {[]}; % Average peak age of tracked targets

                obj.Stats("nTotalTargets") = {[]}; % Total targets in targetModel. Don't need a TotalTargets bc it = 1:nTotalTargets. 
                obj.Stats("nActiveTargets") = {[]}; % Total active targets in targetModel 
                obj.Stats("nObservedTargets") = {[]}; % Number of targets observed in this time step
                obj.Stats("nCoveredTargets") = {[]}; % Number of covered targets in this time step
                obj.Stats("nTrackedTargets") = {[]}; % Number of targets for which a FC track exists in this time step
                obj.Stats("nSelectedNodes") = {[]}; % How many nodes were selected? 
                obj.Stats("nMissedTargets") = {[]}; % How many targets go unobserved? 

                obj.Stats("ActiveTargets") = {[]}; % Index of active targets in targetModel                 
                obj.Stats("ObservedTargets") = {[]}; % Targets observed in this time step
                obj.Stats("CoveredTargets") = {[]}; % Targets covered in this time step (aka total observable targets)
                obj.Stats("TrackedTargets") = {[]}; % Targets for which a FC track exists in this time step                             
                obj.Stats("SelectedNodes") = {[]}; % Which nodes were selected? 
                obj.Stats("SelectionCounts") = {zeros([1,obj.nTrackers])}; % How many times has each node been selected? 

                obj.Stats("TransitionEntropy") = {{[]}}; 

                obj.Stats("TrackError") = {{[]}}; % Error for each track
                obj.Stats("TrackUpdateTimes") = {{[]}}; % Update times for each track
            end
        end % end fusionCenter

        function [] = getUpdates(obj, t)
            % Doesn't really get updates - just iterates the update selection algo
            % Each method (save 'all') should have an average update rate
            % according to the network capacity. 
            % 
            % Options: 
            %   'all': causes all targetTrackers to push updates every time
            %       getUpdates is called
            %   'timely': implements track-sensitive AoI metric from [1]
            %   'bandit': Selects arms according to Upper Confidence Bound
            %   'centralized_random': Selects a constant number of random
            %       nodes for updates based on the update rate. 
            %   'distributed': Implements AoII based distributed updating
            %   'distributed_random': Each node provides updates randomly.
            %       This results in a Poisson number of random updates per
            %       interval with the same mean as centralized_random. 

            % TODO Think if there's a more efficient way of doing the below
            
            % Select nodes
            [selectedNodes] = obj.selectNodes(t); 
            % Analyze the # of selected nodes & how it compares to the
            % desired number

            % Should be an average of td*updateRate*nTrackers

            % This has to go somewhere so I'm putting it here. 
            % ---------------------------
            % Possible Target Transitions
            % ---------------------------
            % For this small section, 'state' refers to target observability. 
            % State Diagram: 
            % -------------------------------------------------------------
            % | All Targets at Time $t$                                   |
            % |                                                           |
            % |  -----------------------------   ------------------------ |
            % |  | All Active Targets        |   | All Retired Targets  | |
            % |  | -----------  ------------||   | ----------- ---------| |
            % |  | | In Range|  |Was seen,  ||   | | Retired | | Other || |
            % |  | | A1      |  | Now Not   ||   | | In Range| | R2    || |
            % |  | -----------  |    A2     ||   | |  R1     | |       || |
            % |  |              -------------|   | ----------- ---------| |
            % |  | ------------------        |   ------------------------ |
            % |  | | Never In Range |        |                            |
            % |  | |     A3         |        |                            |
            % |  | ------------------        |                            |
            % |  -----------------------------                            |
            % -------------------------------------------------------------
            %
            % Valid Non-Degenerate Transitions: 
            % A1 -> R1 | Track Existed, Now Doesn't
            % A1 -> A2 | Track Existed, Now Doesn't 
            % A2 -> A1 | Gap in Coverage
            % A2 -> R2 | Not Observable
            % A3 -> R2 | Not Observable
            % 
            % These omit targets which are in range of nodes not selected! 
            % 

            
            td = t - obj.Time; 
            for i = 1:length(obj.Targets)
                % If target is inactive, no need to process
                if ismember(i, obj.ActiveTargets)
                    % Update age of every target (set to 0 later if update rx)
                    obj.Targets{i}.Age = obj.Targets{i}.Age + td; 
                    obj.Targets{i}.AgeHist(end+1) = obj.Targets{i}.Age; 
                    obj.Targets{i}.ActiveTimes(end+1) = t;                 

                    % Predict each Kalman filter
                    % This happens every time getUpdates is called so that 
                    %   anything output is as correct as possible
                    pstate = predict(obj.Targets{i}.Filter, td); 
                    obj.Targets{i}.FilteredTrack(:,end+1) = pstate; 
                    
                    % Determine the closest node
                    % Need to use activeNodesSeen in order to prevent
                    % assigning a measurement that hasn't occured yet (i.e.
                    % closest node hasn't reported this targ yet)
                    tmp_nodes = obj.activeNodesSeenByTargets{i}; 
                    [~, tmp_closest] = min(vecnorm(pstate([1,3])-obj.NodePositions(:,tmp_nodes))); 
                    obj.Targets{i}.ClosestNode = tmp_nodes(tmp_closest); 
                end
                
            end            

            % Receive updates
            state = zeros(4, length(obj.Targets), length(selectedNodes)); 
            updatedTargets = []; % Transitions A1 -> A1, A2 -> A1
            absentTargets = [];  % Transitions A1 -> R1, A1 -> A2
            newTargets = [];     % Spawned Targets 
            activeTargetMask = []; % Indicates which links are active
            for i = 1:length(selectedNodes)
                update = obj.updateChannels{selectedNodes(i)}.pullUpdate(t); % new syntax
                
                all_tracks = update{1}; 
                activeTargets = update{2}; 
                % active_tracks = {}; 
                if ~isempty(activeTargets)
                    % active_tracks = all_tracks{activeTargets}; 
                end
                
                for j = 1:length(activeTargets)
                    state(:, activeTargets(j), selectedNodes(i)) = all_tracks{activeTargets(j)}.FilteredTrack(:,end); 
                    % Populate obj.activeNodesSeenByTargets...
                    if length(obj.activeNodesSeenByTargets) < activeTargets(j)
                        obj.activeNodesSeenByTargets{activeTargets(j)} = []; 
                    end
                    tmp = union(obj.activeNodesSeenByTargets{activeTargets(j)}, selectedNodes(i)); 
                    obj.activeNodesSeenByTargets{activeTargets(j)} = tmp; 
                end

                updatedTargets = union(updatedTargets, intersect(activeTargets, obj.activeTargetsSeenByNodes{selectedNodes(i)})); 
                absentTargets = union(absentTargets, setdiff(obj.activeTargetsSeenByNodes{selectedNodes(i)}, activeTargets)); 
                newTargets = union(newTargets, setdiff(activeTargets, obj.activeTargetsSeenByNodes{selectedNodes(i)})); 

                tmp = union(obj.activeTargetsSeenByNodes{selectedNodes(i)}, activeTargets)'; 
                % Force to row vector
                obj.activeTargetsSeenByNodes{selectedNodes(i)} = tmp(:).';
                
                tmp = setdiff(obj.ActiveTargets, obj.activeTargetsSeenByNodes{selectedNodes(i)}); 
                % Force to row vector
                obj.activeTargetsNotSeenByNodes{selectedNodes(i)} = tmp(:).'; 

                activeTargetMask(activeTargets, selectedNodes(i)) = 1; 
            end % end for

            % otherNodes = setdiff(1:obj.nTrackers, selectedNodes); 
            % allActiveTargets = union([obj.activeTargetsSeenByNodes{otherNodes}], updatedTargets); 
            
            % It's possible that a target left one region and entered another 
            absentTargets = setdiff(absentTargets, updatedTargets);
            newTargets = setdiff(newTargets, updatedTargets); 


            % Instance new targets
            for i = 1:length(newTargets)
                tmp_state = mean(squeeze(state(:,newTargets(i),activeTargetMask(newTargets(i),:)==1)), 2); 

                obj.Targets{newTargets(i)} = {};
                obj.Targets{newTargets(i)}.Filter = obj.initializeFilter(tmp_state);
                obj.Targets{newTargets(i)}.Track = tmp_state; % Raw observations
                obj.Targets{newTargets(i)}.FilteredTrack = predict(obj.Targets{newTargets(i)}.Filter, 0); % Filtered observations
                obj.Targets{newTargets(i)}.isActive = 1;
                obj.Targets{newTargets(i)}.FlagHistory = []; % "something interesting happened"
                obj.Targets{newTargets(i)}.Age = 0;
                obj.Targets{newTargets(i)}.AgeHist = 0; 
                obj.Targets{newTargets(i)}.PeakAges = []; 
                obj.Targets{newTargets(i)}.State = 0;
                obj.Targets{newTargets(i)}.ModelProb = [0.5, 0.5];
                obj.Targets{newTargets(i)}.Transitions = zeros(2,2);
                obj.Targets{newTargets(i)}.TransitionProb = 0.5*ones(2,2);
                obj.Targets{newTargets(i)}.UpdateTimes = t;
                obj.Targets{newTargets(i)}.ActiveTimes = t; 
                [~, obj.Targets{newTargets(i)}.ClosestNode] = min(vecnorm(tmp_state([1,3])-obj.NodePositions)); 
            end

            % Mark absentTargets as inactive
            for i = 1:length(absentTargets)
                % If the closest node can't see this guy, likely he's gone
                if ismember(obj.Targets{absentTargets(i)}.ClosestNode, selectedNodes)
                    obj.Targets{absentTargets(i)}.isActive = 0; 
                    obj.ActiveTargets = setdiff(obj.ActiveTargets, absentTargets(i)); 
                    for n = 1:obj.nTrackers
                        obj.activeTargetsSeenByNodes{n} = setdiff(obj.activeTargetsSeenByNodes{n}, absentTargets(i)); 
                    end
                % Else, if only the currently polled nodes can't see him, 
                %   remove them from obj.activeNodesSeenByTargets and
                %   obj.activeTargetsSeenByNodes
                else
                    % Remove polled nodes from NbyT
                    tmp_NbyT = setdiff(obj.activeNodesSeenByTargets{absentTargets(i)}, selectedNodes); 
                    obj.activeNodesSeenByTargets{absentTargets(i)} = tmp_NbyT; 
                    % Remove this target from polled nodes TbyN
                    for j = 1:length(selectedNodes)
                        tmp_TbyN = setdiff(obj.activeTargetsSeenByNodes{selectedNodes(j)}, absentTargets(i)); 
                        obj.activeTargetsSeenByNodes{selectedNodes(j)} = tmp_TbyN; 
                    end
                end
            end

            % Lastly, update filters for observed targets
            for i = 1:length(updatedTargets)
                % td = t - obj.Targets{updatedTargets(i)}.UpdateTimes(end); 
                obj.Targets{updatedTargets(i)}.UpdateTimes(end+1) = t; 

                % Decide which measurements to use for correcting
                pstate = obj.Targets{updatedTargets(i)}.FilteredTrack(:,end); % Already calculated above
                obs_nodes = find(activeTargetMask(updatedTargets(i),:)==1); 
                [~, selected_idx] = min(vecnorm(pstate([1,3])-obj.NodePositions(:,obs_nodes))); 
                selected_idx = obs_nodes(selected_idx); 

                % get the measurement 
                tmp_state = state(:, updatedTargets(i), selected_idx); 
                obj.Targets{updatedTargets(i)}.Track(:,end+1) = tmp_state; 

                % Update the appropriate filter
                % Replace the end with this, since it's currently the
                % pstate value
                obj.Targets{updatedTargets(i)}.FilteredTrack(:,end) = correct(obj.Targets{updatedTargets(i)}.Filter, [tmp_state([1,3]); 0]);

                % Update age, etc
                obj.Targets{updatedTargets(i)}.PeakAges(end+1) = obj.Targets{updatedTargets(i)}.Age; 
                obj.Targets{updatedTargets(i)}.Age = 0; % Reset age for updated targets
                obj.Targets{updatedTargets(i)}.AgeHist(end) = 0; % Reset age for updated targets                
            end % end for

            % Update obj.activeTargets: list of all active targets
            obj.ActiveTargets = unique([obj.activeTargetsSeenByNodes{1:end}]); 

            % Record which nodes were selected
            obj.updated_nodes{end+1} = selectedNodes; 
            obj.selectionCounts(selectedNodes) = obj.selectionCounts(selectedNodes) + 1; 

            % Record which targets were seen
            obj.updated_targets{end+1} = union(updatedTargets, newTargets); 

            % Last thing: Update internal time
            obj.Time = t;

            if obj.doStatistics; obj.UpdateStatistics(); end 
        end % end getUpdates

        % Plotters
        function [] = plotScene(obj, plotTracks)
            % Plots current positions of nodes and targets
            if nargin < 2
                plotTracks = 1; 
            end

            % Get node locations
            nodePos = zeros(2, obj.nTrackers); 
            nodeRadius = zeros(1, obj.nTrackers); 
            for i = 1:obj.nTrackers
                nodePos(:,i) = obj.targetTrackers{i}.NodePosition; 
                nodeRadius(:,i) = obj.targetTrackers{i}.ObservableRadius; 
            end % end for

            figure; hold on
            % Draw some lines for the legend
            if plotTracks
                plot(-510:-500, -510:-500, 'g', 'linewidth', 2, 'displayname', 'Active Track')
                plot(-510:-500, -510:-500, 'k', 'DisplayName', 'Retired Track')
            end
            plot(-500, -500, 'xk', 'markersize', 10, 'DisplayName', 'Target Position')
            plot(-500, -500, 'ob', 'markersize', 10, 'DisplayName', 'Node Position')
            plot(-510:-500, -510:-500, '--k', 'linewidth', 2, 'DisplayName', 'Region $B$')
            plot(nsidedpoly(1000, 'Center', [-500, -500], 'Radius', 10), 'FaceColor', 'k', 'DisplayName', '$S_n$')
            for i = 1:obj.targetModel.nTargets
                if obj.targetModel.Targets{i}.isActive
                    tmp = obj.targetModel.Targets{i}.state([1,3]); 
                    plot(tmp(1), tmp(2), 'xk', 'markersize', 10, 'HandleVisibility','off')
                    if plotTracks
                        plot(obj.targetModel.Targets{i}.Track(1,:), obj.targetModel.Targets{i}.Track(3,:), 'g', 'linewidth', 2, 'HandleVisibility','off')
                    end
                else
                    if plotTracks
                        plot(obj.targetModel.Targets{i}.Track(1,:), obj.targetModel.Targets{i}.Track(3,:), 'k', 'HandleVisibility','off')
                    end
                end % end if
            end
            plot(nodePos(1,:), nodePos(2,:), 'ob', 'markersize', 10, 'HandleVisibility','off')
            for i = 1:obj.nTrackers
                plot(nsidedpoly(1000, 'Center', nodePos(:,i)', 'Radius', nodeRadius(i)), 'FaceColor', 'k', 'HandleVisibility','off'); 
            end
            plot([1000, 1000, 0, 0, 1000], [0, 1000, 1000, 0, 0], '--k', 'linewidth', 2, 'HandleVisibility','off')
            xlim([-100, 1100]); 
            ylim([-100, 1100]); 
            legend('interpreter', 'latex', 'location', 'southeast', 'fontsize', 12)
            title('Tracking Region', 'interpreter', 'latex', 'fontsize', 16)
        end % end plotScene       

        function plotTarget(obj, idx)
            % plots FC estimate of target track as well as true target
            % track
            % If idx is an array, plots for all 
            colors = linspecer(length(idx), 'qualitative'); 

            figure; hold on            
            for i = 1:length(idx)
                if ismember(idx(i), obj.ActiveTargets)
                    targ_path = obj.targetModel.Targets{idx(i)}.Track([1,3],:); 
                    targ_track = obj.Targets{idx(i)}.FilteredTrack([1,3], :); 
                    targ_pos = obj.targetModel.Targets{idx(i)}.state([1,3]); 
                    plot(targ_path(1,:), targ_path(2,:), '-', 'color', colors(i,:), 'linewidth', 2, 'HandleVisibility','off')
                    plot(targ_track(1,:), targ_track(2,:), '.', 'color', colors(i,:), 'MarkerSize', 10, 'HandleVisibility','off')
                    plot(targ_pos(1), targ_pos(2), 'x', 'color', colors(i,:), 'markersize', 10, 'HandleVisibility','off')
                end % end if
            end % end for
            % Plots for legend
            plot(-505:-500, -505:-500, '-k', 'linewidth', 2, 'DisplayName', 'Target Path')
            plot(-505:-500, -505:-500, '.k', 'MarkerSize', 10, 'DisplayName', 'Track')
            plot(-505:-500, -505:-500, 'xk', 'markersize', 10, 'displayname', 'Final Position')
            plot(-510:-500, -510:-500, '--k', 'linewidth', 2, 'DisplayName', 'Region $B$')
            plot([1000, 1000, 0, 0, 1000], [0, 1000, 1000, 0, 0], '--k', 'linewidth', 2, 'HandleVisibility','off')
            xlim([-100, 1100]); 
            ylim([-100, 1100]); 
            legend('location', 'best', 'interpreter', 'latex', 'fontsize', 12)
            title('Fused Target Tracks', 'interpreter', 'latex', 'fontsize', 16)
        end % end plotTarget
    end % end public methods
%% Node Selection Routines
    methods(Access=private)
        
        function [selectedNodes] = getAllUpdates(obj, t)
            selectedNodes = 1:obj.nTrackers; 
            for i = 1:obj.nTrackers
                obj.targetTrackers{i}.update(); 
            end
        end % end getAllUpdates

        function [selectedNodes] = getCentralizedRandomUpdates(obj, t)
            % Select nodes
            nNodes = obj.nTrackers * obj.updateRate * (t-obj.Time); % Prob per second
            nNodes = floor(nNodes) + ((nNodes-floor(nNodes))>rand); % Make sure the average is correct
            
            selectedNodes = datasample(1:obj.nTrackers, nNodes, 'Replace', false); 
        end % end getCentralizedRandomUpdates

        function [selectedNodes] = getTimelyUpdates(obj, t)            
            selectedNodes = []; 
            nNodes = obj.nTrackers * obj.updateRate * (t-obj.Time); % Prob per second
            nNodes = floor(nNodes) + ((nNodes-floor(nNodes))>rand); % Make sure the average is correct

            ages = obj.getAges(); 
            availability = obj.getAvailability(); 
            ranges = obj.getRanges(); 
            
            if isempty(ranges) % No targets yet, pick random nodes
                selectedNodes = obj.getCentralizedRandomUpdates(t); 
            else % Have targets, so choose wisely
                [~, S_mat] = obj.getRewardFunction(ages, availability, ranges); 
                candidate_nodes = 1:obj.nTrackers; 
                selectedNodes = zeros(1, nNodes); 
                for i = 1:nNodes
                    if isempty(S_mat) % Exhausted all interesting choices
                        selectedNodes(i) = mink(candidate_nodes, 1); % Random-ish
                    else % Still can choose wisely
                        [max_node, max_target] = find(S_mat == max(S_mat(:)), 1); % Returns one index
                        selectedNodes(i) = candidate_nodes(max_node); 
                        S_mat(max_node, :) = []; 
                        S_mat(:, max_target) = []; 
                    end % end if isempty(S_mat)
                    candidate_nodes(candidate_nodes==selectedNodes(i)) = []; % Remove selection
                end % end for nNodes
            end % end if isempty(ranges)
            % Sanity check
            if any(size(unique(selectedNodes)) ~= size(selectedNodes))
                error('Someting ain''t write cheef')
            end
        end % end getTimelyUpdates

        function [selectedNodes] = getBanditUpdates(obj, t)
            % Figure out nNodes
            nNodes = obj.nTrackers * obj.updateRate * (t-obj.Time); % Prob per second
            nNodes = floor(nNodes) + ((nNodes-floor(nNodes))>rand); % Make sure the average is correct

            avail = obj.getAvailability();
            ranges = obj.getRanges();
            [S] = obj.getRewardFunction(zeros(size(ranges)), zeros(size(ranges)), ranges); 

            if sum(avail) >= nNodes % Play bandit with arms enabled
                [selectedNodes] = obj.Bandit.play(avail, nNodes); 
                idx = 1:nNodes; 
            elseif sum(avail) > 0 % Fill from avail, then play bandit
                selectedNodes(1:sum(avail)) = find(avail); 
                tmp_avail = ones(1, obj.nTrackers); 
                tmp_avail(selectedNodes(1:sum(avail))) = 0; % Ensure no dupes
                selectedNodes(sum(avail)+1:nNodes) = obj.Bandit.play(tmp_avail, nNodes-sum(avail)); 
                idx = sum(avail)+1:nNodes; 
            else % No nodes avail, just use full bandit
                selectedNodes = obj.Bandit.play([], nNodes); 
                idx = 1:nNodes; 
            end % end if 

            obj.Bandit.update(0, S(idx)); 
        end % end getBanditUpdates

        function [selectedNodes] = getDistributedUpdates(obj, t)
            selectedNodes = []; 
            for n = 1:obj.nTrackers
                if obj.updateChannels{n}.aoiiFlag
                    selectedNodes = [selectedNodes, n];
                end
            end % end for

            % Map targets to nodes
            % Probably use 'closest node' approach
            targetAssignment = cell(obj.nTrackers, 0); 
            for n = 1:obj.nTrackers
                targetAssignment{n} = cell(0,0); 
            end % end for nTrackers

            
            delta_ratio = obj.nTrackers / length(obj.ActiveTargets); 
            if isempty(obj.ActiveTargets)
                delta_ratio = 1; 
            end


            for i = 1:length(obj.ActiveTargets)
                pstate = obj.Targets{obj.ActiveTargets(i)}.FilteredTrack(:,end); 
                tmp_nodes = obj.activeNodesSeenByTargets{obj.ActiveTargets(i)}; 
                [~, tmp_closest] = min(vecnorm(pstate([1,3])-obj.NodePositions(:,tmp_nodes))); 
                targetAssignment{tmp_nodes(tmp_closest)}{end+1} = obj.ActiveTargets(i); 
            end % end for activeTargets

            % Calculate any overloaded nodes
            current_deltas = cellfun('length', targetAssignment) * delta_ratio * (t-obj.Time) * obj.updateRate; 
            overloaded_nodes = find(current_deltas > 1); 

            for i = 1:length(overloaded_nodes)
                % Figure out which target(s) to reassign
                current_targs = cell2mat(targetAssignment{overloaded_nodes(i)}); 
                % Get their locations
                ps = zeros(length(current_targs), 2); 
                for j = 1:length(current_targs)
                    ps(j,:) = obj.Targets{current_targs(j)}.FilteredTrack([1,3], end); 
                end
                d = vecnorm(ps.' - obj.NodePositions(:,overloaded_nodes(i))); 
                [d, tmp_targ] = sort(d, 'ascend'); 
                current_targs = current_targs(tmp_targ); % sort
                ps = ps(tmp_targ, :); 
                
                fixed = 0; 
                while fixed == 0
                    other_options = setdiff(obj.activeNodesSeenByTargets{current_targs(end)}, overloaded_nodes); 
                    if ~isempty(other_options)
                        [~, tmp_closest] = min(vecnorm(ps(end, :).'-obj.NodePositions(:,other_options))); 
                        targetAssignment{overloaded_nodes(i)} = num2cell(setdiff(cell2mat(targetAssignment{overloaded_nodes(i)}), current_targs(end))); 
                        targetAssignment{other_options(tmp_closest)}{end+1} = current_targs(end); 
                        fixed = 1; 
                    else
                        current_targs(end) = []; 
                    end
                    
                    % If there's no solution, 
                    if isempty(current_targs)
                        fixed=1; 
                    end
                end
            end

            for n = 1:obj.nTrackers
                obj.updateChannels{n}.setTracks(cell2mat(targetAssignment{n}));
                obj.updateChannels{n}.delta_ratio = delta_ratio; 
            end % end for nTrackers
        end % end getDistributedUpdates

        function [selectedNodes] = getTmpDistributedUpdates(obj, t)
            selectedNodes = []; 
            for n = 1:obj.nTrackers
                if obj.updateChannels{n}.tmpAoiiFlag
                    selectedNodes = [selectedNodes, n];
                    % updatedTargets = obj.updateChannels{n}.tmpUpdateIdx{end}; 
                    % allTargets = obj.updateChannels{n}.updates{end}{1}; 
                    % obj.updateChannels{n}.updates{end}{1} = allTargets(updatedTargets); 
                end
            end % end for

            % Map targets to nodes
            % Probably use 'closest node' approach
            targetAssignment = cell(obj.nTrackers, 0); 
            for n = 1:obj.nTrackers
                targetAssignment{n} = cell(0,0); 
            end % end for nTrackers

            
            delta_ratio = obj.nTrackers / length(obj.ActiveTargets); 
            if isempty(obj.ActiveTargets)
                delta_ratio = 1; 
            end
            % for i = 1:length(obj.ActiveTargets)
            %     pstate = obj.Targets{obj.ActiveTargets(i)}.FilteredTrack(:,end); 
            %     tmp_nodes = obj.activeNodesSeenByTargets{obj.ActiveTargets(i)}; 
            %     [~, tmp_closest] = min(vecnorm(pstate([1,3])-obj.NodePositions(:,tmp_nodes))); 
            %     targetAssignment{tmp_nodes(tmp_closest)}{end+1} = obj.ActiveTargets(i); 
            % end % end for activeTargets

            % Calculate any overloaded nodes
            current_deltas = cellfun('length', targetAssignment) * delta_ratio * (t-obj.Time) * obj.updateRate; 
            overloaded_nodes = find(current_deltas > 1); 

            for i = 1:length(overloaded_nodes)
                % Figure out which target(s) to reassign
                current_targs = cell2mat(targetAssignment{overloaded_nodes(i)}); 
                % Get their locations
                ps = zeros(length(current_targs), 2); 
                for j = 1:length(current_targs)
                    ps(j,:) = obj.Targets{current_targs(j)}.FilteredTrack([1,3], end); 
                end
                d = vecnorm(ps.' - obj.NodePositions(:,overloaded_nodes(i))); 
                [d, tmp_targ] = sort(d, 'ascend'); 
                current_targs = current_targs(tmp_targ); % sort
                ps = ps(tmp_targ, :); 
                
                fixed = 0; 
                while fixed == 0
                    other_options = setdiff(obj.activeNodesSeenByTargets{current_targs(end)}, overloaded_nodes); 
                    if ~isempty(other_options)
                        [~, tmp_closest] = min(vecnorm(ps(end, :).'-obj.NodePositions(:,other_options))); 
                        targetAssignment{overloaded_nodes(i)} = num2cell(setdiff(cell2mat(targetAssignment{overloaded_nodes(i)}), current_targs(end))); 
                        targetAssignment{other_options(tmp_closest)}{end+1} = current_targs(end); 
                        fixed = 1; 
                    else
                        current_targs(end) = []; 
                    end
                    
                    % If there's no solution, 
                    if isempty(current_targs)
                        fixed=1; 
                    end
                end
            end

            for n = 1:obj.nTrackers
                % obj.updateChannels{n}.setTracks(cell2mat(targetAssignment{n}));
                obj.updateChannels{n}.delta_ratio = delta_ratio; 
            end % end for nTrackers
        end % end getTmpDistributedUpdates

        function [selectedNodes] = getDistributedRandomUpdates(obj, t) 
            selectedNodes = []; 
            for n = 1:obj.nTrackers
                if obj.updateChannels.distRandFlag
                    selectedNodes = [selectedNodes, n];
                end
            end % end for
        end % end getDistributedRandomUpdates

        function [selectedNodes] = getRoundRobinUpdates(obj, t)
            nNodes = obj.nTrackers * obj.updateRate * (t-obj.Time); % Prob per second
            nNodes = floor(nNodes) + ((nNodes-floor(nNodes))>rand); % Make sure the average is correct

            % Get last node selected
            tmp = find(~cellfun('isempty', obj.updated_nodes)); 
            if ~isempty(tmp) % case where we've selected nodes before                
                % Handles event where we've selected nodes before, just not
                % in the last time step. 
                last_node = obj.updated_nodes{tmp(end)}(end); 
            else % We haven't selected any before. 
                last_node = obj.nTrackers; % So that the rest starts at 1
            end

            counts = obj.selectionCounts / sum(obj.selectionCounts); 

            if sum(obj.selectionCounts)>0
                selectedNodes = datasample(1:obj.nTrackers, nNodes, 'weights', 1-counts, 'Replace', false);
            else
                selectedNodes = datasample(1:obj.nTrackers, nNodes, 'Replace', false);
            end

            % selectedNodes = mod(last_node:last_node+nNodes-1, obj.nTrackers)+1; 

            % selectedNodes = obj.getCentralizedRandomUpdates(t);


        end % end getRoundRobinUpdates


        % Statistics
        function UpdateStatistics(obj)
            % Calculates stats for all targets in the scene

            obj.Stats{"TimeSteps"}(end+1) = obj.Time; % For plotting
            obj.Stats{"nTotalTargets"}(end+1) = obj.targetModel.nTargets; % Total targets in model
            obj.Stats{"nActiveTargets"}(end+1) = obj.targetModel.nActiveTargets; 
            obj.Stats{"nObservedTargets"}(end+1) = length(obj.updated_targets{end}); 
            obj.Stats{"nSelectedNodes"}(end+1) = length(obj.updated_nodes{end}); 
            obj.Stats{"nTrackedTargets"}(end+1) = length(obj.ActiveTargets); 
            obj.Stats{"nMissedTargets"}(end+1) = obj.targetModel.nTargets - length(obj.ActiveTargets); 

            obj.Stats{"ObservedTargets"}{end+1} = obj.updated_targets{end}(:); 
            obj.Stats{"SelectedNodes"}{end+1} = obj.updated_nodes{end}; 
            obj.Stats{"TrackedTargets"}{end+1} = obj.ActiveTargets; 
            obj.Stats{"SelectionCounts"}(obj.updated_nodes{end}) = obj.Stats{"SelectionCounts"}(obj.updated_nodes{end}) + 1; 


            % All targets
            tmp_covered_targets = []; 
            tmp_active_targets = []; 
            err = []; 
            age = []; 
            peak_age = []; 
            for i = 1:obj.targetModel.nTargets
                % Determine if target is covered                     
                % if ~ismember(i, obj.updated_targets{end})
                %     % if ismember(i, obj.ActiveTargets) && ...
                %     if obj.targetModel.Targets{i}.isActive && ...
                %             norm(obj.targetModel.Targets{i}.state([1,3])' ...
                %             - obj.NodePositions(:, obj.Targets{i}.ClosestNode)) ...
                %             < obj.targetTrackers{obj.Targets{i}.ClosestNode}.ObservableRadius
                %         tmp_covered_targets = union(tmp_covered_targets, i);
                %     else 
                %         [closestRange, closestNode] = min(vecnorm(obj.targetModel.Targets{i}.state([1,3]).'-obj.NodePositions)); 
                %         if closestRange < obj.targetTrackers{closestNode}.ObservableRadius
                %             tmp_covered_targets = union(tmp_covered_targets, i);
                %         end
                %     end % end norm
                % end % end ismember
                [closestRange, closestNode] = min(vecnorm(obj.targetModel.Targets{i}.state([1,3]).'-obj.NodePositions)); 
                if closestRange < obj.targetTrackers{closestNode}.ObservableRadius && obj.targetModel.Targets{i}.isActive
                    tmp_covered_targets = union(tmp_covered_targets, i);
                end


                % If it's still active AND there's a track for it, 
                if obj.targetModel.Targets{i}.isActive 
                    % Add to ActiveTargets
                    tmp_active_targets = union(tmp_active_targets, i); 
                    if ismember(i, obj.ActiveTargets)
                        err(end+1) = norm(obj.targetModel.Targets{i}.state([1,3])' - obj.Targets{i}.FilteredTrack([1,3], end)); 
                        age(end+1) = obj.Targets{i}.Age; 
                        if ~isempty(obj.Targets{i}.PeakAges)
                            peak_age(end+1) = mean(obj.Targets{i}.PeakAges); 
                        else
                            peak_age(end+1) = 0; 
                        end
                        
                        try % We've already established this variable
                            obj.Stats{"TrackError"}{i}(end+1) = err(end); 
                            obj.Stats{"TrackUpdateTimes"}{i}(end+1) = obj.Time; 
                        catch % Need to establish the variable
                            obj.Stats{"TrackError"}{i} = []; 
                            obj.Stats{"TrackUpdateTimes"}{i} = []; 
                            obj.Stats{"TrackError"}{i}(end+1) = err(end); 
                            obj.Stats{"TrackUpdateTimes"}{i}(end+1) = obj.Time; 
                        end
                    end % end if ismember

                    % Update transition entropy
                    if i > length(obj.Stats{"TransitionEntropy"})
                        obj.Stats{"TransitionEntropy"}{i} = obj.targetModel.Targets{i}.EntropyRate; 
                    elseif isempty(obj.Stats{"TransitionEntropy"}{i})
                        obj.Stats{"TransitionEntropy"}{i} = obj.targetModel.Targets{i}.EntropyRate; 
                    end

                    % Update age for each target. Seems like a bad way but oh well. 
                    obj.Stats{"TargetAge"}{i} = obj.targetModel.Targets{i}.Age; 
                end % end if isActive
            end
            
            if ~isempty(err) % Also proxy for age
                obj.Stats{"Error"}(end+1) = mean(err); 
                obj.Stats{"RMSE"}(end+1) = sqrt(mean(err.^2)); 
                obj.Stats{"Age"}(end+1) = mean(age); 
                obj.Stats{"PeakAge"}(end+1) = mean(peak_age); 
            else
                obj.Stats{"Error"}(end+1) = 0; 
                obj.Stats{"RMSE"}(end+1) = 0; 
                obj.Stats{"Age"}(end+1) = 0; 
                obj.Stats{"PeakAge"}(end+1) = 0; 
            end
            obj.Stats{"ActiveTargets"}{end+1} = tmp_active_targets; 
            obj.Stats{"CoveredTargets"}{end+1} = tmp_covered_targets; %union(tmp_covered_targets, obj.updated_targets{end}); 
            obj.Stats{"nCoveredTargets"}(end+1) = length(obj.Stats{"CoveredTargets"}{end}); 

        end % end updateStatistics

        % Getters
        function [ranges] = getRanges(obj)
            % Returns current estimated range for all active targets
            ranges = zeros(obj.nTrackers, length(obj.ActiveTargets)); 
            for t = 1:length(obj.ActiveTargets)
                ranges(:, t) = vecnorm(obj.Targets{obj.ActiveTargets(t)}.FilteredTrack([1,3], end) - obj.NodePositions); 
            end
        end

        function [ages] = getAges(obj)
            ages = zeros(length(obj.ActiveTargets), 1); 
            for t = 1:length(obj.ActiveTargets)
                ages(t) = obj.Targets{obj.ActiveTargets(t)}.Age; 
            end
        end

        function [avail] = getAvailability(obj)
            avail = zeros(obj.nTrackers, 1); 
            for i = 1:obj.nTrackers
                avail(i) = obj.updateChannels{i}.isAvailable; 
            end
        end

        function [S, S_mat] = getRewardFunction(obj, ages, availability, ranges)
            alpha = 0.1; % Discount factor for unavailable nodes
            beta = 0.5; % Exploration factor for nodes we haven't touched in a while (measure this by # new targets since node selected)
            gamma = -0.2; % Penalty for # unobservable targets at node

            % Increment ages to avoid zero values
            ages = ages + 1; 

            S = zeros(obj.nTrackers, length(obj.Targets)); % Do a sneaky: We know that all targets < max(obj.ActiveTargets) must exist... 
            for i = 1:obj.nTrackers
                for j = 1:length(obj.ActiveTargets)
                    % if ranges(i, j) < obj.targetTrackers{i}.ObservableRadius % node can see target
                    if ismember(obj.ActiveTargets(j), obj.activeTargetsSeenByNodes{i}) % node can see target
                        tmp = ages(j).^2 / sqrt(ranges(i,j)); % TODO: Not sure what this should actually be
                        if availability(i)
                            S(i, obj.ActiveTargets(j)) = tmp; % Overweighted age; inverse of variance
                        else 
                            S(i, obj.ActiveTargets(j)) = alpha * tmp; % Discount for node unavailable
                        end
                    elseif ismember(obj.ActiveTargets(j), obj.activeTargetsNotSeenByNodes{i})
                        S(i, obj.ActiveTargets(j)) = gamma; % Penalty for can't see this target
                    else
                        S(i, obj.ActiveTargets(j)) = beta; % Don't know so explore the world! 
                    end
                end
            end


            S_mat = S; 
            S = sum(S(:, obj.ActiveTargets), 2); 
            
        end % end getRewardFunction        
    end % end private methods

    methods(Static)
        function filter = initializeFilter(state)
            state = [state([1,3]); 0];
            detection = objectDetection(0, state, "MeasurementNoise", [1, 0.4, 0; 0.4, 1, 0; 0, 0, 1]);
            filter = initekfimm(detection);
            % filter = trackingIMM();
            % [~] = predict(filter, 0);
            % [~] = correct(filter, state);
        end % end initializeFilter
    end % end static methods
end

