function Strats = strat_assign(strategies, nActions, n_players, ID, varargin)
%STRAT_ASSIGN Summary of this function goes here
%   Detailed explanation goes here
Strats = cell(2, 1);


switch strategies{1}
    case "MC_TopM"
        Strats{1} = MC_TopM(nActions(1), ID, n_players, varargin);
    case "MC"
        Strats{1} = MC(nActions(1), ID, n_players, varargin);
    case "C_and_P"
        Strats{1} = C_and_P(nActions(1), ID, n_players, varargin);
    case "orthog"
        Strats{1} = orthog(nActions(1), ID, n_players, varargin);
    case "SAA"
        Strats{1} = SAA(nActions(1), ID, n_players, varargin);
        % Now for "bad guy" strategies
    case "Follower"
        Strats{1} = Follower(nActions(1), ID, n_players, varargin);
    case "NoOp"
        Strats{1} = NoOp(nActions(1), ID, n_players, varargin);
    case "CentralizedExploreFirst"
        Strats{1} = CentralizedExploreFirst(nActions(1), ID, n_players, varargin); 
    case "RandomMatching"
        s = RandStream('mt19937ar','Seed', 69420); 
        Strats{1} = RandomMatching(nActions(1), ID, n_players, s, varargin); 
end

switch strategies{2}
    case "eGreedy"
        s = cell(1,nActions(1));
        for i = 1:nActions(1)
            s{i} = eGreedy(nActions(2), i, n_players, varargin);
        end
        Strats{2} = s;
    case "eDecaying"
        s = cell(1,nActions(1));
        for i = 1:nActions(1)
            s{i} = eDecaying(nActions(2), i, n_players, varargin);
        end
        Strats{2} = s;
    case "NoOp"
        s = cell(1,nActions(1));
        for i = 1:nActions(1)
            s{i} = NoOp(nActions(2), i, n_players, varargin);
        end
        Strats{2} = s;
    case "SAA"
        s = cell(1,nActions(1));
        for i = 1:nActions(1)
            s{i} = SAA(nActions(2), i, n_players, varargin);
        end
        Strats{2} = s;
    case "subFollower"
        s = cell(1,nActions(1));
        for i = 1:nActions(1)
            s{i} = subFollower(nActions(2), i, n_players, varargin);
        end
        Strats{2} = s;
end

end

