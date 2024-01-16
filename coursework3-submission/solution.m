% Define file names
target_file = 'target_trajectory.txt';
actual_file = 'actual_trajectory.txt';


% 1). Read in the data from the text files and determine whether they exist or not.
% Check if files exist
if ~exist(target_file, 'file') || ~exist(actual_file, 'file')
    error('One or both of the files do not exist. Please check the file paths.');
else
    % If they do exist, load in the data.
    disp('The file(s) exist.');
    actual_data = load("actual_trajectory.txt");
    target_data = load("target_trajectory.txt");
end


% Index to splice out the samples to ignore form the beginning and end
ignoreSamples = 50;
act_data = actual_data((ignoreSamples + 1) : (end - ignoreSamples), :);
tgt_data = target_data((ignoreSamples + 1) : (end - ignoreSamples), :);


% 2). Calculate the mean and max distances between the both trajectory data
[mui_dist, max_dist] = calc_distances(act_data,tgt_data);


% 3). Find the temporal shift between the actual and target trajectories.
[opt_delay, smallest_MeanD] = opt_temporal_delay(act_data,tgt_data);


% 4). Find MeandD and MaxD after delay correction
aligned_actual = act_data(opt_delay+1:end,:);
aligned_target = tgt_data(1:(end - opt_delay), :);
[corrected_mean_d, corrected_max_d] = calc_distances(aligned_actual, aligned_target);


% 5). The time away from the trajectory, and the consistent time
[time_away, consistent_time] = time_away_from_traj(aligned_actual, aligned_target);


% 6). Display subplot of original actual, delay-corrected actual and tagret trajectories, only first 200 samples.
display_results(opt_delay,time_away,consistent_time,mui_dist, ...
    corrected_mean_d,max_dist,corrected_max_d)

% Initialize x-axis timeline and index arrays for these points.
x = 1:200;
actual_x = actual_data(x,1);
actual_y = actual_data(x,2);
actual_z = actual_data(x,3);
target_x = tgt_data(x,1);
target_y = tgt_data(x,2);
target_z = tgt_data(x,3);

% Plot subplot 1 for 'actual vs target' trajector
figure;
subplot(2,1,1);
plot(x,actual_x,x,actual_y,x,actual_z)
hold on;
plot(x,target_x,x,target_y,x,target_z)
hold off;
xlabel('Time (ms)')
ylabel('Position [m]')
title('target vs. actual')
legend('Actual X','Actual Y','Actual Z', 'Target X','Target Y','Target Z')

subplot(2,1,2);
plot(x,target_x,x,target_y,x,target_z);
hold on;
plot(x,aligned_actual(x,1),x,aligned_actual(x,2),x,aligned_actual(x,3))
hold off;
xlabel('Time (ms)')
ylabel('Position [m]')
title('target vs. delay-corrected actual')
legend('Actual X','Actual Y','Actual Z', 'Target X','Target Y','Target Z')









