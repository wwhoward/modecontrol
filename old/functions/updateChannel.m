classdef updateChannel < handle
    %UPDATECHANNEL Written for TTT Journal by W.W.Howard in Spring 2023
    %   Allows information exchange between targetTracker and many
    %   fusionCenters
    % Usage: 
    % FC distributes one updateChannel per node
    % Every time a radar node does radar, it pushes an update to
    % updateChannel: obj.pushUpdate
    % 
    % The FC pulls updates through obj.pullUpdate(t), where t is the
    % current time. 

    % isAvailable: Indicates that this node saw something interesting. 
    % For centralized use. 

    % aoiiFlag: Indicates that this node desires to push an AoII update. 
    % For distributed use. 

    % distRandFlag: Indicates that this node desires to push a distributed
    % random update. Obviously for distributed use. 

    % Generally, to guarentee that the same group of nodes can cooperate
    % with several FC's, it's important to /only pull/ information with FC,
    % never push. 
    % For ex: if FC.updateChannel.setNewUpdate, alternate FCs will not see
    % the update. 

    
    properties
        updateTimes = []
        updates = {}
        isAvailable = 0 
        aoiiFlag = 0
        tmpAoiiFlag = 0
        distRandFlag = 0 
        tracks = [] % Currently at most one AOII FC per network
        delta_ratio = 0; 

        tmpUpdateIdx = {}
    end
    
    methods
        function obj = updateChannel()
            %UPDATECHANNEL Provides updates from targetTracker to fusionCenter
        end

        function [] = pushUpdate(obj, time, tracks, active_targets)
            % pushUpdate pushes time and tracks to updateChannel
            % Should be called in every time step
            obj.updateTimes(end+1) = time; 
            obj.updates{end+1} = {tracks, active_targets}; 
            % obj.updateFlag = 1; 
            % obj.isAvailable = 0; 
        end

        function [] = tmpPushUpdate(obj, update_idx)
            obj.tmpUpdateIdx{end+1} = update_idx; 
        end

        function [update] = pullUpdate(obj, time)
            % pullUpdate used by fusionCenter to receive latest updates
            update = obj.updates{obj.updateTimes == time}; 
        end

        function [] = setAvailability(obj, flag)
            % Used in centralized mode
            obj.isAvailable = flag; 
        end

        function [] = setAoiiFlag(obj, flag)
            obj.aoiiFlag = flag; 
        end

        function [] = setTmpAoiiFlag(obj, flag)
            obj.tmpAoiiFlag = flag; 
        end

        function [] = setDistRandFlag(obj, flag)
            obj.distRandFlag = flag; 
        end

        function tracks = getTracks(obj)
            tracks = obj.tracks; 
        end % end getTracks

        function setTracks(obj, tracks)
            obj.tracks = tracks; 
        end % end setTracks
    end
end

