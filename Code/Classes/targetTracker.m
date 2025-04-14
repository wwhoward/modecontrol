classdef targetTracker < handle
    % TARGETTRACKER Tracks targets in 'targetModel'
    %   Functions as a single cognitive radar node. Works with 'fusionCenter' and
    %   'targetModel'. 
    % Version information: 
    %   3.1 8/8/23 Updated during initial phase of Mode Control journal
    %       - Adds support for multiple target 'classes' as well as
    %       estimation of those
    %       - Space now has three dimensions
    %       - Implements filter tuning
    %   3.0 Spring 2023 used in Timely Target Tracking journal
    %   2.0 Used for timely target tracking conference
    % 
    % Primarily for the study of Age of Information metrics as applied to
    % Cognitive Radar Networks. 
    % 
    % Also built with mode control in mind... 
    % 
    % Contact: {wwhoward}@vt.edu Wireless@VT
    
    properties
        nTargets = 0        % Estimate of how many targets are observable

        Targets = {}        % Set of all targets ever observed
        ActiveTargets = []  % Set of targets recently observed
        TargetClass = []    % Must be estimated if empty, otherwise known
        FilterType = 'untuned'% Load tuning parameters or use untuned? {'tuned', 'untuned'}

        Age = []            % Age for each track. Stops updating when isActive=0. 
        ageThreshold = 5    % TODO
        innovationThreshold = 5 % TODO
        masterUpdateFlag = 0
        masterUpdateAge = 0
        masterUpdateAgeMax = 3

        ObservableRadius    % Determine how target is observed
        regionCoverage = 0.1 % Percent of region covered by this node
        NodePosition        % Self explanitory
        sideSize = 10000; 

        ID                  % Unique to this node
        nTrackers           % How many total nodes

        time = 0

        updateChannels
        updateMethods = {}; % Populated by FC (if no FC, no updateMethods). Also serves to indicate how many client FCs 
        updateRate = 0.1; 
        
        % Mode control additions
        signalTypes = {"1", "2", "3"} % TODO Sam
        n_signalTypes = 3
        Classes = {} % Used to determine which 
        Modes = {"active", "passive", "null"} % Do radar, do sig class, do nothing
        ModeSelection = 'Centralized' % either 'Centralized' or 'Distributed'
        % currentMode = {'active', 'passive'} % both
        currentMode = {{'active'}}
        UseTrueClasses = true
        

        % Version info 
        version = '3.1'
    end
    
    methods(Access=public)
        function obj = targetTracker(ID, nTrackers, varargin)
            %TARGETTRACKER Tracks targetModel targets, works with fusionCenter
            % Reqired inputs: 
                % ID: unique ID for this node
            % Optional inputs: 
                % 'Coverage': value in [0,1] denoting percentage of region covered by this node 
                % Note due to random positioning, set 'Coverage' to 2pi to guarentee total region coverage
            
            obj.ID = ID; 
            obj.nTrackers = nTrackers; 

            % Parse optional inputs
            % Valid optional inputs: 'Coverage', 'updateRate'
            
           
            if any(strcmp(varargin, 'Coverage')) % covered region
                idx = find(strcmp(varargin, 'Coverage'));
                obj.regionCoverage = varargin{idx+1};
            end

            if any(strcmp(varargin, 'updateRate')) % node update rate
                idx = find(strcmp(varargin, 'updateRate'));
                obj.updateRate = varargin{idx+1};
            end

            if any(strcmp(varargin, 'FilterType')) % Type of filter
                idx = find(strcmp(varargin, 'FilterType'));
                obj.FilterType = varargin{idx+1};
            end

            if any(strcmp(varargin, 'TargetClass')) % Do we know the target class?
                idx = find(strcmp(varargin, 'TargetClass'));
                obj.TargetClass = varargin{idx+1};
            end

            if any(strcmp(varargin, 'NodePosition')) % Is there a preferred location?
                idx = find(strcmp(varargin, 'NodePosition'));
                obj.NodePosition = varargin{idx+1};
            else
                obj.NodePosition = obj.sideSize*rand(2, 1); % Somewhere in 10 square km
            end
            
            % Define observable region            
            obj.ObservableRadius = sqrt(obj.regionCoverage * obj.sideSize^2/pi); 

            obj.updateChannels = updateChannel(); 
        end

        function [Targets] = observe(obj, targetModel, time)
            % targetModel: targets needing observing
            % time: current time
            
            time_step = time - obj.time; % For AoII tx probs
            obj.time = time; 
            flags = zeros(1, obj.nTargets); 

            [state, idx] = targetModel.getState('active'); 
            motion = state.motion; 
            signal = state.signal; 

            % Iterate through all possible new target IDs 
            % Target ID is constant so any new targets will have ID > length(obj.Targets)
            % Also, all target states & idx are provided, so we need to determine if each is observable
            % TODO: Replace this clunky struct with a class
            % TODO make separate external target object generator, use in
            % both fusionCenter and targetTracker
            for i = length(obj.Targets)+1:max(idx) % We see all targets
                % if this i is still active, instance target for it
                % Only way i is not active is if it retired before we observed it
                obj.Targets{i} = {}; 
                obj.Targets{i}.Track = []; % Raw observations
                obj.Targets{i}.FilteredTrack = []; % Filtered observations
                obj.Targets{i}.isActive = 1; 
                % obj.Targets{i}.FlagHistory = []; % "something interesting happened"
                obj.Targets{i}.Age = 0; 
                obj.Targets{i}.Penalty = obj.time; 
                obj.Targets{i}.V = 0; % Last updated at t=0
                obj.Targets{i}.State = 0; 
                obj.Targets{i}.StateHat = -1; 
                obj.Targets{i}.ModelProb = [1, 1, 1]/3; % TODO base on actual number of motion models
                obj.Targets{i}.Transitions = zeros(3,3); % TODO base on actual number of motion models
                obj.Targets{i}.TransitionProb = 0.5*ones(2,2); 
                obj.Targets{i}.IsNew = 1; % lets FC know we're new
                obj.Targets{i}.UpdateTimes = time; 
                obj.Targets{i}.SignalType = []; 
                obj.Targets{i}.SignalProb = zeros(1,obj.n_signalTypes); 
                obj.Targets{i}.ClassDists = {}; 

                if obj.UseTrueClasses
                    obj.Targets{i}.EstimatedClass = targetModel.Targets{i}.Class.class; 
                    obj.Targets{i}.Filter = obj.initializeFilter(motion(:,idx==i)); 
                    obj.Targets{i}.Filter = obj.initializeFilter(motion(:,idx==i), ...
                                     obj.Targets{i}.EstimatedClass, ...
                                     obj.Targets{i}.Filter); 
                else
                    obj.Targets{i}.EstimatedClass = 0; 
                    obj.Targets{i}.Filter = obj.initializeFilter(motion(:,idx==i)); 
                end

                flags(i) = 1; % If there's a new target, flag it! 
                obj.ActiveTargets(end+1) = i;                 
            end % end for

            % Now, iterate through the targets and update each one if it's observable
            transition_inactive = []; 
            transition_active = []; 
            for i = 1:length(idx)
                % Check for observability
                dist = norm(obj.NodePosition - motion([1,3],i)); 
                % TODO Include probability of interception
                if dist > obj.ObservableRadius % not in range
                    obj.Targets{idx(i)}.IsNew = 0; 
                    % Check for active -> inactive transition
                    if ~isempty(intersect(obj.ActiveTargets, idx(i))) % transition case
                        transition_inactive(end+1) = idx(i); 
                        obj.Targets{idx(i)}.isActive = 0; % Set as inactive so it won't be in updates
                        obj.ActiveTargets = setdiff(obj.ActiveTargets, idx(i)); % Remove from active targets
                    end % end if                    
                else    
                    % Check for inactive -> active transition
                    if isempty(intersect(obj.ActiveTargets, idx(i))) % transition case
                        transition_active(end+1) = idx(i); 
                        obj.ActiveTargets = union(obj.ActiveTargets, idx(i)); % Add to active targets if in range
                        obj.Targets{idx(i)}.isActive = 1;
                    end % end if
    
                    % Some notes on target tracking: 
                    % obj.Targets{}.Filter is an Interacting Motion Model filter
                    % It evaluates between three different possible motion models 
                    %   cv, ct, ca
                    % 
                    % obj.Targets{}.Track stores the raw observed [x,y]
                    % pstates is the [x vx y vy z vz] prediction
                    % cstates is the [x vx y vy z vz] correction
                    % obj.Targets{}.FilteredTrack stores the corrected [x,y]
                    % The filter is 3D because Old Will couldn't 2D it
    
                    % The variance for a track is based on the true range
                    % We know that it's only detected if 0<dist<100 so...
                    variance = (dist/obj.ObservableRadius)*0.1; 
    
                    % Since targets may enter and exit the region ... 
                    td = time - obj.Targets{idx(i)}.UpdateTimes(end); 
                    obj.Targets{idx(i)}.UpdateTimes(end+1) = time;    
                    pstates = predict(obj.Targets{idx(i)}.Filter, td); 
                    
                    % Decide which modes to use (probably just one at a
                    % time, but allowing multiple as well)

                    % Active radar
                    if any(contains(obj.currentMode{end}, 'active'))
                        obj.Targets{idx(i)}.Track(:,end+1) = variance*randn(3,1) + motion([1:2:end],i); 
                        pstates = predict(obj.Targets{idx(i)}.Filter, td); 
                        cstates = correct(obj.Targets{idx(i)}.Filter, obj.Targets{idx(i)}.Track(:,end)); 
                    else
                        pstates = predict(obj.Targets{idx(i)}.Filter, td); 
                        cstates = pstates; 
                    end
                    
                    % Passive classification
                    if any(contains(obj.currentMode{end}, 'passive'))
                        % Determine signal parameters
                        obj.Targets{idx(i)}.SignalType(end+1) = obj.estimateSignalType(signal(i)); 
                        for s = 1:obj.n_signalTypes
                            obj.Targets{idx(i)}.SignalProb(s) = sum(obj.Targets{idx(i)}.SignalType==s)/sum(obj.Targets{idx(i)}.SignalType>=0); 
                        end
                    end


                    obj.Targets{idx(i)}.FilteredTrack(:,end+1) = cstates; 
    
                    % Update transition probabilities
                    tmpModelProbs = obj.Targets{idx(i)}.Filter.ModelProbabilities'; % Current estimated model probabilities
                    obj.Targets{idx(i)}.ModelProb(end+1, :) = tmpModelProbs ./ sum(tmpModelProbs); % renormalize; store in history
                    [~, states] = max(obj.Targets{idx(i)}.ModelProb(end-1:end,:), [], 2); % Peek most recent two model probabilities; take max to get expected models
                    tmp = zeros(length(tmpModelProbs), length(tmpModelProbs)); % Indicator where transitions occur
                    tmp(states(1), states(2)) = 1; % Indicator where transition occured
                    obj.Targets{idx(i)}.Transitions = obj.Targets{idx(i)}.Transitions + tmp; % Save in average history
                    if ~any(sum(obj.Targets{idx(i)}.Transitions, 2)==0)
                        obj.Targets{idx(i)}.TransitionProb = obj.Targets{idx(i)}.Transitions./sum(obj.Targets{idx(i)}.Transitions, 2); 
                    end % end if
                    obj.Targets{idx(i)}.State = states(2); 

                    % Calculate distances to target classes
                    obj.Targets{idx(i)}.ClassDists{end+1} = obj.getDistanceToClasses(obj.Targets{idx(i)}); 
                    change_filter = false; 
                    if ~isempty(obj.Targets{idx(i)}.ClassDists{end})
                        [~, tmp_class] = min(obj.Targets{idx(i)}.ClassDists{end}); 
                        if obj.Targets{idx(i)}.EstimatedClass ~= tmp_class
                            change_filter = true; 
                        end
                        obj.Targets{idx(i)}.EstimatedClass = tmp_class; 
                    end

                    if change_filter 
                        obj.Targets{idx(i)}.Filter = obj.initializeFilter(cstates, obj.Classes{tmp_class}.trueClassEst, obj.Targets{idx(i)}.Filter); 
                    end

                end % end ifelse
                flags(transition_active) = 1; % Flag active transitions
                flags(transition_inactive) = 1; % Flag inactive transitions
            end % end for

            % Choose the next mode
            obj.selectNextMode(); 

            % Push update to updateChannel
            obj.update(flags, time_step); 

            % Optionally output all target tracks
            Targets = obj.Targets; 
        end % end observe

        function selectNextMode(obj)
            % Use current info to select mode at t+1
            switch obj.ModeSelection
                case 'Centralized'
                    % Do nothing
                case 'Distributed'
                    % Now we have to do something
                    modes = {'active', 'passive'}; 
                    metric = obj.getModeMetric(); % Note does not need to be normalized
                    selected_mode = datasample(modes, 1, 'weights', metric); 

                    obj.currentMode{end+1} = selected_mode; 
            end

        end % end selectNextMode

        function metric = getModeMetric(obj)
            % Calculate utility for current targets 
            metric = [0, 0]; 
            age = zeros(1, length(obj.ActiveTargets)); 

            for i = 1:length(obj.ActiveTargets)
                % age(i) = obj.Targets(obj.ActiveTargets(i)).Age
                age(i) = obj.time - obj.Targets{obj.ActiveTargets(i)}.UpdateTimes(1); % Age is current time minus first update time

                if age(i)==0; age(i) = 1; end

                % Using fixed duration now; TODO replace with class prior
                if age(i) <= 0.75 % ok since age(age==0)=1
                    metric = metric + (1/age(i) * [0.5, 0.5]); 
                else
                    tmp_class = obj.Targets{obj.ActiveTargets(i)}.EstimatedClass; 
                    if 0==1 && tmp_class > 0 && ~obj.Classes{tmp_class}.isTenative % TODO remove first argument
                        metric = metric + (1/age(i) * obj.Classes{tmp_class}.Prior); 
                    else
                        metric = metric + (1/age(i) * [0.8, 0.2]); 
                    end
                end
            end

            if any(isnan(metric)) || all(metric==0)
                % Failed for some reason, set default
                metric = [0.8, 0.2]; 
            end                
        end % end getModeMetric

        function [dists] = getDistanceToClasses(obj, target)
            dists = zeros(1, length(obj.Classes)); 
            ModelProb = target.ModelProb; 
            SignalProb = target.SignalProb; 
            for i = 1:length(obj.Classes)
                if ~obj.Classes{i}.isTenative % Don't use tenative classes, they're probably wrong
                    % dists(i) = vecnorm(abs(obj.Classes{i}.class_vector - [ModelProb(end,:), SignalProb]), 2); 
                    dists(i) = 0.25 * vecnorm(abs(obj.Classes{i}.class_vector(1:3) - ModelProb(end,:))) + ...
                               0.75 * vecnorm(abs(obj.Classes{i}.class_vector(4:6) - SignalProb)); 
                else
                    error('Classes shouldn''t be tenative')
                    dists(i) = 100000; 
                end
            end
        end
        
        function [] = update(obj, flags, time_step)
            % Manages update types, pushes new info to updateChannel

            % This is for the centralized techniques
            if any(strcmp(obj.updateMethods, 'centralized'))
                if any(flags) && 0.2<rand
                    obj.updateChannels.setAvailability(1);
                else
                    obj.updateChannels.setAvailability(0);
                end
                obj.updateChannels.pushUpdate(obj.time, obj.Targets, obj.ActiveTargets)
            end

            if any(strcmp(obj.updateMethods, 'distributed_random'))
                obj.sendRandomUpdates(); 
                obj.updateChannels.pushUpdate(obj.time, obj.Targets, obj.ActiveTargets)
            end

            if any(strcmp(obj.updateMethods, 'distributed'))
                obj.sendAoiiUpdates(time_step); 
                obj.updateChannels.pushUpdate(obj.time, obj.Targets, obj.ActiveTargets)
            end
        end % end update

        % Setters
        function [] = addUpdateMethod(obj, method)
            % Determines when targetTracker posts updates to updateChannel
            if ~any(strcmp(obj.updateMethods, method))
                obj.updateMethods{end+1} = method; 
            end % end if 
        end % end setUpdateMethod
        

        % Getters
        function [state, idx] = getState(obj)
            % getState: returns current Kalman state for all targets
            % recently active
            % "recently active" -> ismember(obj.ActiveTargets)

            state = zeros(4, length(obj.ActiveTargets)); 
            idx = obj.ActiveTargets; 

            for i = 1:length(obj.ActiveTargets)
                pstates = predict(obj.Targets{obj.ActiveTargets(i)}.Filter, 0); 
                state(:,i) = pstates; 
            end % end for
        end % end getState

        function [targets, idx] = getTargets(obj, status)
            switch status 
                case 'all'
                    targets = obj.Targets{obj.ActiveTargets}; 
                    idx = obj.ActiveTargets; 
                case 'active'
                    targets = obj.Targets; 
                    idx = 1:length(obj.Targets); 
            end
        end
        
        function [dets] = getDetections(obj, status)
            dets = {}; 
            % Returns objectDetections for all targets
            for t = 1:length(obj.Targets)
                dets{t} = {}; 
                for i = 1:size(obj.Targets{t}.Track, 2)
                    dets{t}{i} = objectDetection(obj.Targets{t}.UpdateTimes(i+1), ...
                                                 obj.Targets{t}.Track(:,i)); 
                end
            end

        end % end function getDetections

    end % end public methods
    
    %% Update Methods
    methods(Access=private)
        function [] = sendCentralizedUpdates(obj)
            % Do nothing; FC prompts updates when necessary
        end % end sendCentralizedUpdates

        function [] = sendRandomUpdates(obj)
            % Randomly sends an update with a mean of updateRate
             % First, reset newUpdate flag
            obj.updateChannels.setDistRandFlag(0); 

            if rand < obj.updateRate
                obj.updateChannels.setDistRandFlag(1); 
            end % end if
        end

        function [] = sendAoiiUpdates(obj, td)
            % First, reset newUpdate flag
            obj.updateChannels.setAoiiFlag(0); 
            
            % Initialize internal flag
            doUpdate = 0; 

            % Get which tracks FC prescribes
            myTracks = obj.updateChannels.getTracks(); 

            % Multiply myTracks by the total entropy rate
            sumER = obj.totalEntropyRate(myTracks); 
            if sumER == 0 || isnan(sumER) || isinf(sumER) % avoid edge cases
                sumER = 0.5*length(myTracks); % must be early on & we don't know much yet, so give ave capacity. 
            end

            % Update rate           

            % This is the best one so far
            % delta_bar = 1*length(myTracks)*max(1, obj.updateChannels.delta_ratio)*td * obj.updateRate; 
            delta_bar = 3*sumER*max(1, obj.updateChannels.delta_ratio)*td * obj.updateRate; 

            

            % Determine state for each tracked target
            % Penalty: S_m(t) = (t-V_m(t))
            
            % Check for retirees
            if ~all(ismember(myTracks, obj.ActiveTargets)) 
                % warning('Target allocation seems wrong')
                doUpdate = 1; % Unsure if this is best but should work to communicate new retiree
            end

            % Now get penalty for each target, flagging if exceeded
            for i = 1:length(obj.Targets)
                % Reset V if state is correct                

                % Conditions to trigger update
                % First, if it's new
                if obj.Targets{i}.IsNew && td > 0 && rand < 0.895^length(obj.Targets) % IsNew only used here! But reset in a  few lines
                    doUpdate = 1; 
                end

                % Second, if threshold indicates
                if ismember(i, myTracks) && ismember(i, obj.ActiveTargets)
                    P = obj.Targets{i}.TransitionProb; 
                    if any(P(:)==0)
                        er = 0.5; % avoid NaN case
                    else
                        er = obj.getEntropyRate(P); 
                    end

                    % Get threshold for each target
                    thresh = obj.optimalThresholdFinder(obj.Targets{i}.TransitionProb(1,2), delta_bar); 

                    % Get update probability per second
                    update_prob = (delta_bar - obj.A_n(thresh+1, er)) / (obj.A_n(thresh, er) - obj.A_n(thresh+1, er)); 
                    if ((obj.time - obj.Targets{i}.V) >= thresh && rand < update_prob)
                        doUpdate = 1; 
                    elseif ((obj.time - obj.Targets{i}.V) >= thresh+1 && rand < (1-update_prob))
                        doUpdate = 1; 
                    end
                end
                
                % Don't bother with the rest of the loop if we're already
                % updating
                if doUpdate
                    break
                end
            end

            if doUpdate
                for i = 1:length(obj.ActiveTargets)
                    obj.Targets{obj.ActiveTargets(i)}.V = obj.time; 
                    obj.Targets{obj.ActiveTargets(i)}.StateHat = obj.Targets{obj.ActiveTargets(i)}.State; 
                    obj.Targets{obj.ActiveTargets(i)}.IsNew = 0; % Now longer new if doUpdate
                end
                obj.updateChannels.setAoiiFlag(1); 
            end % end if doUpdate
        end

        function [thresh] = optimalThresholdFinder(obj, p1, delta_bar)
            % Implements optimal threshold algorithm from 'AoII paper'

            N_LB = 1; 
            N_UB = 1; 

            while obj.A_n(N_UB, p1) - delta_bar >= 0
                N_LB = N_UB; 
                N_UB = 2*N_UB; 
            end

            n_prime = ceil((N_LB + N_UB)/2); 
            while n_prime < N_UB
                if (obj.A_n(n_prime, p1) - delta_bar) >=0
                    N_LB = n_prime; 
                else
                    N_UB = n_prime; 
                end
                n_prime = ceil((N_LB + N_UB)/2); 
            end

            thresh = n_prime - 1; 
        end % end optimalThresholdFinder

        function [sumER] = totalEntropyRate(obj, myTargets)
            ER = zeros(1, length(myTargets)); 
            for i = 1:length(myTargets)
                ER(i) = obj.getEntropyRate(obj.Targets{myTargets(i)}.TransitionProb); 
            end
            sumER = sum(ER); 
        end


    end % end private methods
    
    %% Other private methods
    methods(Access=private)
        function filter = initializeFilter(obj, state, class, current_filter)
            % state = [state([1,3]); 0];
            state = state([1,3,5]); 
            detection = objectDetection(0, state, "MeasurementNoise", 10*[1, 0.4, 0; 0.4, 1, 0; 0, 0, 1]);
            filter = initekfimm(detection);
            
            % Use MaxNumSmoothingSteps as isTuned indicator
            filter.MaxNumSmoothingSteps = 1; 

            % filter = trackingIMM(); 
            % predict(filter, 0); 
            % correct(filter, state); 

            if nargin > 2
                if obj.UseTrueClasses %&& rand > 0.75 %TODO remove second argument
                    [~, motion] = targetModel.getStaticTargetParams(class);  
                    mc = dtmc(motion);

                    filter = current_filter; 
                    tmp_props = {}; 
                    tmp_props.ModelProbabilities = asymptotics(mc); 
                    tmp_props.TransitionProbabilities = motion; 
                    tmp_props.TrackingFilters = filter.TrackingFilters; 
                    setTunedProperties(filter, tmp_props); 
                    filter.MeasurementNoise = [1, 0.4, 0; 0.4, 1, 0; 0, 0, 1]; 

                elseif class > 0 && class <= 3
                    filter = current_filter; 
                    props = load('tuned_filters_tmp/Class'+string(class)+'_props.mat', ...
                        'Class'+string(class)+'_props');
                    field = fieldnames(props); 
                    props = props.(field{1}); 
                    tmp_props = {}; 
                    tmp_props.ModelProbabilities = props.ModelProbabilities; 
                    tmp_props.TransitionProbabilities = props.TransitionProbabilities; 
                    tmp_props.TrackingFilters = filter.TrackingFilters; 
                    setTunedProperties(filter, tmp_props); 
                    filter.MeasurementNoise = [1, 0.4, 0; 0.4, 1, 0; 0, 0, 1]; 
                    % filter.MaxNumSmoothingSteps = 2; % part of a bad plan, delete me
                else
                    error('Filter selection not yet implemented, please provide a TargetClass. ')
                end
            end
        end % end initializeFilter

        function signal_out = estimateSignalType(obj, signal_in)
            signal_out = signal_in; % TODO Sam
        end % end estimateSignalType
    end
    
    %% Internal Methods
    methods(Static)
        % Internal magic (don't let the smoke out) 
        

        function A = A_n(n, p1)
            % Implements A from 'AoII paper', sets N=2
            % A is the portion of time a packet is sent. 
            % p1 is the probability that the state does not change. 
            % a is
            % b is
            % n is the proposed threshold
            a = 1-p1; 
            b = p1; 

            c1 = (1-p1) * b^(n-1); 
            c2 = (1-p1) * (1-b^n) / (1-b); 
            c3 = (1-p1) * a * b^(n-1) / (1-a); 

            A = c1 / ((1-a)*(1+c2+c3)); 
        end % end A_n

        function er = getEntropyRate(P) 
            [V,D] = eig(P.'); 
            idx=find(abs(diag(D)-1)==min(abs(diag(D)-1))); 
            st = V(:,idx).' / sum(V(:,idx)); % Normalize
            er = 0; 
            for i = 1:length(st)
                if st(i) > 0
                    tmp = -sum(st(i)*P(i,:) .* log2(P(i,:))); 
                    tmp(isnan(tmp))=0; 
                    er = er +tmp; 
                end
            end
            % er = -sum(st(1)*P(1,:).*log2(P(1,:)))-sum(st(2)*P(2,:).*log2(P(2,:)));
        end
        
        % Plotters
        function plotTrack(estTarget, Target)
            est_track = estTarget.Track; 
            filt_track = estTarget.FilteredTrack; 
            track = Target.Track; 
            
            figure; 
            plot(track(1,:), track(3,:)); 
            hold on
            plot(est_track(1,:), est_track(2,:), '.'); 
            plot(filt_track(1,:), filt_track(3,:), 'linewidth', 2); 
            % plot(track(1,Target.FlagHistory(1:size(track,2))==1), track(3,Target.FlagHistory(1:size(track,2))==1), 'x'); 
            % plot(filt_track(1,estTarget.FlagHistory(1:size(est_track,2))==1), filt_track(3,estTarget.FlagHistory(1:size(est_track,2))==1), 'o')
            legend('Track, age=' + string(Target.Age), 'Estimated Track', 'Filtered Track', 'Events', 'Flags', 'interpreter', 'latex', 'fontsize', 12); 
        end % end plotTrack


    end % end static methods
end

