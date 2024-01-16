function [total_time_away,consistent_time] = time_away_from_traj(acc_array, tgt_array)
   % Usage: Determine the time the delay-corrected actual trajectory was more than 2 mm away from the target trajectory.
    % Inputs: 
        % corrected_acc_traj = the delay-corrected data of the actual trajectory
        % target_traj = the target trajectory data
    % Outputs:
        %   time_away = total time corrected trajectory is away from the target trajectory
        %   consistent_time = total time the corrected trajectory is consistently more than 2 mm away from the target trajectory for at least 3 ms (three successive measurements)


% Calculate the distances between the delay-corrected and target
% trajectories
traj_dist_diff = sqrt(sum((acc_array - tgt_array).^2, 2));
 
% Initialize counters
total_time_away = 0;    % keeps track of total time away from the trajectory
consistent_time = 0;    % keep track of when time away from traj was for more than 3 measurements
count = 0;              % count the number of times base condition is met

% Loop through the array of distances calculated at each (measurement) point
for i = 1:length(traj_dist_diff)

    % Check if ditance at each measurement interval satisifes base case: distance being > 2mm
    if traj_dist_diff(i) > 0.002
        % Increment count accordingly
        count = count + 1;
    else
        % update the total time away to the value of count
        total_time_away = total_time_away + count;
        % Take into account measurement noise to determine consistent time away.
        if count >= 3
            % Increment consistent time away to count also
            consistent_time = consistent_time + count;
        end
        % Reset count for next iteration
        count = 0;
    end

end

