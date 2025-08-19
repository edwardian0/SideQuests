#pragma once

#include <string>
#include <vector>

#include "image.h"

// Utility function set to perform variuous operations on the image data


// struct to store hte contrast agent information
struct ContrastAgent
{
    std::string agent_name;
    double dose;
};

// Load in the contrast agent data
ContrastAgent load_contrast_info(const std::string& filename);


// Funciton to compute the average signal S(d) in the LVBP region for eachtime frame
std::vector<double> compute_average_signal (const std::vector<Image<int>>& dataset, const BinaryImage& bin_img ,int centreX, int centreY, int maskSize);


// Function to compute the gradient of the (average) signal timecourse
std::vector<double> signal_gradient(const std::vector<double>& signal_timecourse);


// Funciton to compute the temporal gradient of the signal timecourse
double temporal_gradient(double S_peakBlood, double S_arrival, int d_peakBlood, int d_arrival);
