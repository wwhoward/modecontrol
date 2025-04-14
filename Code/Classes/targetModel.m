classdef targetModel < handle
    %targetModel simulates a group of multiple targets with shared properties
    %   Version info: 
    %       3.1 8/3/23 Updated during initial phase of Mode Control journal
    %           - Adds support for multiple target 'classes'
    %               - SUV, UAV, civilian aircraft each with their own characteristic motion 
    %               - Targets have characteristic signal models
    %           - TTT-style motion modeling is depreciated
    %           - The third (z) spatial dimension finally exists
    %           - obj.exportTimeSeries() returns target track formatted as
    %           a time series object. Implemented to enable filter tuning. 
    %       3.0 Used in Timely Target Tracking journal
    %           - Targets evolve over time according to i.i.d. motion
    %           model
    %           - Targets retire if they leave bounded area
    %       2.0 Used for Timely Target Tracking conference
    %           - No underlaying motion model; targets go in straight lines
    %           or turn instantly
    % 
    % Contact: {wwhoward}@vt.edu Wireless @ VT

    
    properties % note only global properties, targets have their own as well
        % Cell array to hold target objects
        Targets

        % How many targets in each stage of life
        nActiveTargets      % Current active targets
        nRetiredTargets     % Current retired targets
        nTargets            % Current total targets

        % Desired mean # of targets
        saturation = 30

        % Spawn and retire probabiliities per second
        % Configured to hover around saturation
        pRetire = 0.01     % Influences target track duration
        pSpawn              % Initialized in constructor

        % Motion modeling
        motionTypes = {"const_v", "const_t", "const_a"} 
        n_motionTypes = 3

        % Signal modeling
        signalTypes = {"1", "2", "3"} % TODO Sam
        n_signalTypes = 3
        
        % Targt class info
        targetClasses = {1, 2, 3} % Each class has characteristics
        targetClassNames = {"SUV", "Drone", "Civ. Aircraft"}
        targetClassProbabilities = [1, 1, 1]/3 

        % Regions
        sideSize = 10000; % 10km
        spawnRegion
        aliveRegion         
        maxVals = []
        minVals = []
        maxVelocity = [100, 100, 100]
        
        % Keep track of the current time
        time

        % Version info
        version = '3.1'
    end
    
    methods(Access=public)
        function obj = targetModel(initialTargets, varargin)
            %TARGETMODEL Handles target motion modeling
            
            obj.nTargets = initialTargets; % initial total targets
            obj.time = 0; % zero-indexing time

            % Regions
            l0 = obj.sideSize; 
            l1 = obj.sideSize - 100; 
            obj.maxVals = [l1, l1, l1]; 
            obj.minVals = [100, 100, 0]; 
            obj.spawnRegion = polyshape([100, l1, l1, 100], [100, 100, l1, l1]); 
            obj.aliveRegion = polyshape([0, l0, l0, 0], [0, 0, l0, l0]); 

            
            % Parse varargin
            if any(strcmp(varargin, 'pRetire'))
                idx = find(strcmp(varargin, 'pRetire')); 
                obj.pRetire = varargin{idx+1}; 
            end

            if any(strcmp(varargin, 'targetClassProbabilities'))
                idx = find(strcmp(varargin, 'targetClassProbabilities')); 
                obj.targetClassProbabilities = varargin{idx+1}; 
            end
            

            % Populate initial targets
            for i = 1:initialTargets
                obj.Targets{i} = obj.newTarget(obj.time); 
            end
            obj.update(0);            

            obj.pSpawn = obj.pRetire*obj.saturation; 
        end % end constructor

        function obj = update(obj, t)
            obj.time = obj.time + t; 

            % Update existing targets
            for i = 1:obj.nTargets
                if obj.Targets{i}.isActive
                    obj.Targets{i} = obj.updateTarget(obj.Targets{i}, t); 
                end % end if
            end % end for

            % Check for retirees to update internal tracking
            activeTargets = 0; 
            for i = 1:obj.nTargets
                if obj.Targets{i}.isActive
                    activeTargets = activeTargets + 1; 
                end % end if
            end % end for
            obj.nActiveTargets = activeTargets; 

            % Generate new targets according to Poisson
            % Modifier to add elasticity around saturation point
            rubber = (obj.pSpawn>0)*(obj.saturation - obj.nActiveTargets); 
            newTargs = poissrnd(t*obj.pSpawn + t*(rubber/10)); 
            if isnan(newTargs); newTargs = 0; end
            % newTargs = poissrnd(t*obj.pSpawn); 
            for i = 1:newTargs
                obj.Targets{end+1} = obj.newTarget(obj.time); 
                obj.nActiveTargets = obj.nActiveTargets + 1; 
            end
            obj.nTargets = size(obj.Targets, 2); 

            % Calc nRetired
            obj.nRetiredTargets = obj.nTargets - obj.nActiveTargets; 
        end % end update      

        % Getters
        function [state, idx, tracks] = getState(obj, activityType)
            % Returns target states by career status
            % state is a struct with keys "motion" and "signal"

            idx = []; 
            tracks = {}; 
            state = struct(); 
            switch activityType
                case "all"
                    motion = zeros(6, obj.nTargets); 
                    signal = zeros(1, obj.nTargets); 
                    for i = 1:obj.nTargets
                        motion(:,i) = obj.Targets{i}.state; 
                        signal(:,i) = obj.Targets{i}.CurrentSignal; 
                        tracks{end+1} = obj.Targets{i}.Track; 
                        idx(end+1) = i; 
                    end % end for

                case "active"
                    motion = zeros(6, obj.nActiveTargets); 
                    signal = zeros(1, obj.nActiveTargets); 
                    j=1; 
                    for i = 1:obj.nTargets
                        if obj.Targets{i}.isActive
                            motion(:,j) = obj.Targets{i}.state; 
                            signal(:,j) = obj.Targets{i}.CurrentSignal; 
                            tracks{end+1} = obj.Targets{i}.Track; 
                            j=j+1; 
                            idx(end+1) = i; 
                        end % end if
                    end % end for

                case "retired"
                    motion = zeros(6, obj.nRetiredTargets); 
                    signal = zeros(1, obj.nRetiredTargets); 
                    j=1; 
                    for i = 1:obj.nTargets
                        if ~obj.Targets{i}.isActive
                            motion(:,j) = obj.Targets{i}.state; 
                            signal(:,j) = obj.Targets{i}.CurrentSignal; 
                            tracks{end+1} = obj.Targets{i}.Track; 
                            j=j+1; 
                            idx(end+1) = i; 
                        end % end if
                    end % end for
            end % end switch
            state.motion = motion;
            state.signal = signal;
        end % end getState

        function [mean_age, ages] = getAge(obj)
            ages = []; 
            for i = 1:obj.nTargets
                ages(end+1) = obj.Targets{i}.Age; 
            end % end for

            mean_age = mean(ages); 
        end % end getAge

        function ER = getEntropyRate(obj)
            T = obj.Targets{1}.Transition; 
            asy = asymptotics(dtmc(T)); 
            ER = 0; 
            for i = 1:size(T, 1)
                for j = 1:size(T, 2)
                    ER = ER + -asy(i) * T(i,j) * log2(T(i,j)); 
                end
            end
        end

        function params = getTargetParams(obj, targetClass)
            % Stores distributions for each target class
            % Notes on signal types
            params = struct(); 
            [tmp_signal, tmp_motion] = obj.getStaticTargetParams(targetClass); 
            params.signal = tmp_signal; 
            params.model_transition = tmp_motion; 
            
            switch targetClass
                % Class 1: SUV
                % Description: always on the ground, zero vertical velocity
                case 1
                    params.x_range = [[obj.minVals(1), obj.maxVals(1)]; ...
                                      [obj.minVals(1), obj.maxVals(2)]; ...
                                      [0,              0]]; % Box in which target can spawn
                    params.v_range = [[0, obj.maxVelocity(1)/10]; ...
                                      [0, obj.maxVelocity(1)/10]; ...
                                      [0, 0]]; % Valid velocities
                
                % Class 2: UAV
                % Description: Can go any speed in any direction
                case 2
                    params.x_range = [[obj.minVals(1), obj.maxVals(1)]; ...
                                      [obj.minVals(1), obj.maxVals(2)]; ...
                                      [0,              obj.maxVals(3)]]; % Box in which target can spawn
                    params.v_range = [[0, obj.maxVelocity(1)]; ...
                                      [0, obj.maxVelocity(2)]; ...
                                      [0, obj.maxVelocity(3)]]; % Valid velocities

                % Class 3: Aircraft
                % Description: Goes fast and high but doesn't go slow or low
                case 3
                    params.x_range = [[obj.minVals(1), obj.maxVals(1)]; ...
                                      [obj.minVals(1), obj.maxVals(2)]; ...
                                      [obj.maxVals(3)/2, obj.maxVals(3)]]; % Box in which target can spawn
                    params.v_range = [[obj.maxVelocity(1)/2, obj.maxVelocity(1)]; ...
                                      [obj.maxVelocity(2)/2, obj.maxVelocity(2)]; ...
                                      [obj.maxVelocity(3)/2, obj.maxVelocity(3)]]; % Valid velocities

            end % end switch
            % params.model_transition = params.model_transition + 0.05*rand(3,3); 
            params.acceleration = 20*rand(1,3) - 10; 

            % Determine stationary distribution
            mc = dtmc(params.model_transition); 
            params.model_probs = asymptotics(mc); 
            if size(params.model_probs, 1)>1
                error('Looks like motion model isn''t right; not ergodic! ')
            end

        end % end getTargetParams

        % Setters
        function [] = set_pRetire(obj, pRetire)
            obj.pRetire = pRetire; 
            obj.pSpawn = obj.pRetire * obj.saturation; 
        end
    end % end public methods

    methods(Access=protected)
        % For updating
        function targ = updateTarget(obj, targ, t)
            targ.Age = targ.Age + t; 
            targ.updateTimes(end+1) = targ.Age; 

            % First things: Update motion type
            current_idx = targ.motion; 
            n_models = obj.n_motionTypes; 
            trans = targ.Class.model_transition(current_idx, :); 
            trans(setdiff(1:n_models, current_idx)) = t*trans(setdiff(1:n_models, current_idx)); 
            trans(current_idx) = 1-sum(trans(setdiff(1:n_models, current_idx))); 
            new_idx = randsample(1:n_models, 1, true, trans); 
            if new_idx ~= current_idx
                targ.motion = new_idx; 
                
                if current_idx == 1 && new_idx == 2
                    % Transition 1: const vel to const turn
                    % Update turn rate
                    targ.turn_rate = -1 + 2*rand; %Somewhere from -1:1
                elseif current_idx == 2 && new_idx == 1
                    % Transition 2: const turn to const vel
                    % Update vel
                    targ.state(2:2:end) = 0.1*randn*targ.state(2:2:end) + targ.state(2:2:end); % Randomly scale current velocity ~90:110%

                % TODO: Fill in the rest of the transitions for accel model

                end % end if
            end % end if

            % Second things: Update state
            switch obj.motionTypes{targ.motion}
                case 'const_v'
                    % Simply prop current vel

                    % Determine new position 
                    targ.state(1:2:end) = targ.state(1:2:end) + t*targ.state(2:2:end); 
                case 'const_t'
                    % Get heading from vel, update pos, update vel

                    % Determine current heading
                    heading = atan2(targ.state(4), targ.state(2)); 

                    % Update heading according to turn rate
                    heading = heading + t*targ.turn_rate*5;

                    % Determine new velocity
                    speed = sqrt(targ.state(2)^2 + targ.state(4)^2); 
                    targ.state(2:2:4) = speed * [cos(heading), sin(heading)]; 

                    % Determine new position
                    targ.state(1:2:end) = targ.state(1:2:end) + t*targ.state(2:2:end); 
                case 'const_a'
                    % Update velocity at the /start/ of each time step,
                    % then increment position
                    targ.state(2:2:end) = (t * targ.Class.acceleration) + targ.state(2:2:end); 

                    targ.state(1:2:end) = targ.state(1:2:end) + t*targ.state(2:2:end); 
                    % TODO
            end % end switch

            % n^th things n^th (where n < 3)
            % Update signal transmitted
            targ.CurrentSignal = datasample(1:obj.n_signalTypes, 1, 'Weights', targ.Class.signal); 


            % Third things: 
            % Can we retire yet? 
            if isinterior(obj.aliveRegion, targ.state([1,3]))
                if isinterior(obj.spawnRegion, targ.state([1,3]))
                    tmp_pRetire = obj.pRetire; 
                else
                    tmp_pRetire = 10*obj.pRetire; 
                end
            else
                tmp_pRetire = 100*obj.pRetire; 
            end
            if rand < t*tmp_pRetire && targ.Age > 1 % try to prevent stillbirths
                targ.isActive = 0; 
            end % end if 

            targ.Track(:, end+1) = targ.state; 
        end % end updateTarget
        
        % For initializing
        function targ = newTarget(obj, initTime)
            targ = struct(); 
            targ.initialTime = initTime; 
            targ.updateTimes = initTime; 
            targ.isActive = 1; 
            targ.Age = 0; 

            % Initialize target type
            targ.Class = obj.getTargetClass;             

            % Get initial position and velocity (these change according to target class) 
            pos = (targ.Class.x_range(:,2)-targ.Class.x_range(:,1)).*rand(3,1) + targ.Class.x_range(:,1); % give some buffer so they can move out of spawn
            vel = (targ.Class.v_range(:,2)-targ.Class.v_range(:,1)).*rand(3,1) + targ.Class.v_range(:,1); 

            % Set initial motion info
            targ.turn_rate = -1 + 2*rand;
            targ.state = zeros(1,6); % this updates in each time step to always be current
            targ.state([1,3,5]) = pos; 
            targ.state([2,4,6]) = vel;             
            targ.Track(:,1) = targ.state; % State history
            targ.motion = randsample([1:3], 1, true, targ.Class.model_probs); 

            % Determine initial signal behavior
            targ.CurrentSignal = datasample(1:obj.n_signalTypes, 1, 'Weights', targ.Class.signal); 
        end % end newTarget

        function targetClass = getTargetClass(obj)
            % Samples available classes, generates relevant params
            targetClass = struct(); 

            tmp_class = datasample(1:length(obj.targetClasses), 1, 'Weights', obj.targetClassProbabilities); 
            targetClass = obj.getTargetParams(tmp_class); 
            targetClass.class = tmp_class; 
        end % end getTargetClass 
    end % end protected methods

    methods(Static)
        % Plotty boys
        function plotTrackProjection(targ)
            track = targ.Track; 
            xy = track([1,3],:); 
            
            figure; 
            plot(xy(1,:), xy(2,:))
            legend('Track (Duration = ' + string(targ.Age) + ')', 'interpreter', 'latex', 'fontsize', 12)
            title('Target Path', 'interpreter', 'latex', 'fontsize', 16)
            xlabel('x, meters', 'interpreter', 'latex', 'fontsize', 12)
            ylabel('y, meters', 'interpreter', 'latex', 'fontsize', 12)
            zlabel('z, meters', 'interpreter', 'latex', 'fontsize', 12)
        end % end plotTrackProjection

        function plotTrack(targ)
            track = targ.Track; 
            xyz = track(1:2:end,:); 

            figure; 
            plot3(xyz(1,:), xyz(2,:), xyz(3,:))
            grid on
            legend('Track ('+string(targ.Age) + 's, class='+string(targ.Class.class)+')', 'interpreter', 'latex', 'fontsize', 12)
            title('Ground Track', 'interpreter', 'latex', 'fontsize', 16)
            xlabel('x, meters', 'interpreter', 'latex', 'fontsize', 12)
            ylabel('y, meters', 'interpreter', 'latex', 'fontsize', 12)
        end % end plotTrack

        function plotnTargets(nTargets)
            figure; 
            plot(nTargets); 
            hold on
            yline(mean(nTargets)); 
            xlabel('Number of Active Targets', 'interpreter', 'latex', 'fontsize', 12)
        end % end plotnTargets

        function [signal, motion] = getStaticTargetParams(class)
            switch class
                case 1
                    signal = [0.9, 0, 0.1]; % Probability of each signal type
                    motion = [[0.9 0.09 0.01]; ...
                              [0.495 0.495 0.01]; ...
                              [1/3 1/3 1/3]]; % TODO fill in more realistic model

                    % Class 2: UAV
                    % Description: Can go any speed in any direction
                case 2
                    signal = [0.1, 0.9, 0];
                    motion = [[1/3 1/3 1/3]; ...
                              [1/3 1/3 1/3]; ...
                              [1/3 1/3 1/3]]; % TODO fill in more realistic model

                    % Class 3: Aircraft
                    % Description: Goes fast and high but doesn't go slow or low
                case 3
                    signal = [0, 0.1, 0.9];
                    motion = [[0.9 0.01 0.09]; ...
                              [0.05   0.9 0.05]; ...
                              [0.09 0.01 0.9]]; % TODO fill in more realistic model
            end % end switch
        end % end getStaticTargetParams

    end % end static methods
end % end class

