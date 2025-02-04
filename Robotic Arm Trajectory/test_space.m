clear
actual_data = load("actual_trajectory.txt");
target_data = load('target_trajectory.txt');


min_mean_dist = 0.0038;
delay_range = 0:1:50;
opt_delay = 0;

for delay = delay_range

    acc_shifted = actual_data(delay+1:end, :);
    tgt_shifted = target_data(1:(end - delay), :);

    mui_dist = sqrt(sum((acc_shifted - tgt_shifted).^2, 2));
    
    if (mui_dist < min_mean_dist)
        min_mean_dist = mui_dist;
        opt_delay = delay;
    end 

end

acc_shift = actual_data((1+opt_delay):end,:);
tgt_shift = target_data(1:(end - opt_delay), :);
distances = sqrt(sum((acc_shift - tgt_shift).^2, 2));
time_away = 0;
consistent_time = 0;

for i=1:length(distances)
    
    if distances(i) > 0.002
        consistent_time = consistent_time + 1;
        
        if consistent_time >= 3
            time_away = time_away + 1;
        end
    
    end

end
disp(time_away)