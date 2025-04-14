classdef UCB < handle
    
    properties
        Acts = [] % Action history
        Cols = [] % Collision history
        Rews = [] % Reward history
        Means = [] % Current means
        vector_rewards = []
        
        Actions = [] % Set of actions
        n_pulls = [] % Set of selections per action
        n_actions = [] % Measure of actions
        ID % Unique (to the network) identifier for this node
        
        n_players % Total players
        
        ActionHistory = []
        RewardHistory = []
        CollisionHistory = []
        CumCols = 0
        
        lastAction = []
        lastCollision = []
        
        delay
        T = 1
        
        % Unique
        n_selections
        c
        Q
    end
    
    methods
        function obj = UCB(n_actions, ID, n_players, varargin)
            %UCB Implemented for TTT Journal in Spring 2023 by WWHoward
            % Contact: wwhoward@vt.edu, wireless @ vt
            obj = strat_constructor(obj, n_actions, ID, n_players, varargin); 
            
            
            if any(strcmp(varargin, 'n_selections'))
                obj.n_selections = varargin{find(strcmp(varargin, 'n_selections')==1)+1};
            else
                obj.n_selections = 1; 
            end

            if any(strcmp(varargin, 'c'))
                obj.c = varargin{find(strcmp(varargin, 'c')==1)+1};
            else
                obj.c = 1; 
            end

            obj.Q = zeros(1, n_actions); 
        end
        
        function action = play(obj, availability, k)                
            % ucb = obj.RewardHistory(end,:) ./ obj.n_pulls + obj.c * sqrt(log(t) ./ obj.n_pulls); 
            
            if isempty(k)
                k = obj.n_selections; 
            end

            if isempty(availability)
                availability = ones(1, obj.n_actions); 
            end


            [~, tmp] = maxk(obj.Q(availability==1), k); 
            avail_nodes = find(availability); 
            action = avail_nodes(tmp); 
            
            

            % obj.Acts(end+1, :) = action; 
            obj.lastAction = action; 
        end
        
        function [] = update(obj, obs, rew)
            obj = obj.ucb_strat_updater(obs, rew);      
            
            obj.Q = obj.Means + (obj.c * (sqrt(log(obj.T+1) ./ obj.n_pulls))); 
            
        end

        function obj = ucb_strat_updater(obj, obs, rew)
            if obj.T>length(obj.Rews)
                obj.Rews = [obj.Rews, zeros(obj.n_actions, 5000)]; 
            end
            if obj.T > length(obj.Cols)
                obj.Cols = [obj.Cols, zeros(1, 5000)]; 
            end
            if obj.T > size(obj.vector_rewards, 1)
                obj.vector_rewards = [obj.vector_rewards, zeros(5000, obj.n_selections)]; 
            end
            
            
            obj.CumCols = obj.CumCols + obs; 
            obj.Cols(obj.T) = obs; 
            if obj.lastAction ~= 0
                if size(rew,1)==1
                    rew = rew.'; 
                end
                obj.Means(obj.lastAction) = (obj.n_pulls(obj.lastAction).*obj.Means(obj.lastAction) + rew)./(obj.n_pulls(obj.lastAction)+1); 
                obj.n_pulls(obj.lastAction) = obj.n_pulls(obj.lastAction) + 1; 
                obj.Rews(obj.lastAction, obj.T) = rew; 
                % obj.vector_rewards(obj.T, :) = rew; 
            end
            
            
            
            if length(obj.Cols) <= obj.delay
                obj.lastCollision = 0; 
            else
                obj.lastCollision = obj.Cols(obj.T - obj.delay); 
            end
            
            obj.T = obj.T+1; 
        end

    end
end

