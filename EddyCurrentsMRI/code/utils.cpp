#include <vector>
#include <string>
#include <fstream>

#include "utils.h"

// Definitnion of the declared utility functions

// Load in the contrast agent data
ContrastAgent load_contrast_info(const std::string& filename) {
    std::ifstream infile(filename);
    
    if (!infile) {
        throw std::runtime_error("Unable to open file \"" + filename + "\"");
    }

    ContrastAgent contrast_agent;
    
    if (!(infile >> contrast_agent.agent_name >> contrast_agent.dose)) {
        throw std::runtime_error("[ERROR]: Parameter file \"" + filename + "\" is empty or incorrectly formatted");
    }

    return contrast_agent;
}


// Function ot compute the average signal S(d) in the LVBP region for eachtime frame d
std::vector<double> compute_average_signal (const std::vector<Image<int>>& dataset, const BinaryImage& bin_img ,int centreX, int centreY, int maskSize) {
    int half_size = maskSize / 2;
    std::vector<double> average_signal;  // Store S(d) for each frame

    for (const auto& frame : dataset) {
        double sum = 0.0;
        int pixel_count = 0;

        // Dynamically compute the 5x5 region
        for (int y = centreY - half_size; y <= centreY + half_size; ++y) {
            for (int x = centreX - half_size; x <= centreX + half_size; ++x) {
                // Check if current pixel is within the mask region (i.e value is 1)
                if (bin_img(x, y) == 1) {
                    // Get pixel value from the image and add to sum
                    sum += frame(x, y);  
                    // Increment the pixel count
                    ++pixel_count;
                }
                
            }
        }
        double avg_signal = sum / pixel_count;  // Compute S(d)
        average_signal.push_back(avg_signal);
    }


    // Return the computed average signal timecourse
    return average_signal;
}


std::vector<double> signal_gradient(const std::vector<double>& signal_timecourse) {
    
    std::vector<double> gradient_timecourse;
    // Loop throught the signal timecourse to compute the gradient
    for (int d = 1; d < signal_timecourse.size() - 1; ++d) {
        // Cmpute the gradient as the difference between the current and next time point 
        gradient_timecourse.push_back(signal_timecourse[d + 1] - signal_timecourse[d]);
    }
    
    // Reconcile to 0
    gradient_timecourse.push_back(0);
    return gradient_timecourse;
}


// Function to compute the temporal gradient of the signal timecourse
double temporal_gradient(double S_peakBlood, double S_arrival, int d_peakBlood, int d_arrival) {
    // To prevent division by zero, check to see if d_arrival and d_peakBlood are the same
    if (d_arrival == d_peakBlood) {
        throw std::runtime_error("d_arrival and d_peakBlood cannot be the same to compute the temporal gradient");
    }
    return (S_peakBlood - S_arrival) / (d_peakBlood - d_arrival);
}
