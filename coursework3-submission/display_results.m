function  [] = display_results(delay,time_away,consistent_time,mui_dist,min_mui_dist,max_dist,corrected_max_d)
% Usage: Display the final key results of the program.
% Inputs: 
        % delay: THe optimal temporal delay found.
        % time_away: Total time away from the trajectory
        % consistent_time: Time trajectory was consistently awya from the trajectory
        % mui_dist: Mwan distance between the actual and target trajectories
        % min_mui_dist: Smallest mean distance found from the delay-corrected data
        % max_dist: Maximum distance between found between the actual and target trajectories
        % corrected_maxD: Maximum distance found between the delay-corrected actual & target trajectories

% Ouptut(s): Void

% Display in format required
fprintf('delay: %f\n',delay);
fprintf('totalTimeAwayFromTraj: %d\n', time_away);
fprintf('consistentTimeAway:    %d\n',consistent_time);
fprintf('meanD (init: %f; corrected: %f)\n',mui_dist,min_mui_dist);
fprintf('maxD  (init: %f; corrected: %f)\n\n',max_dist,corrected_max_d);

return

end

