#include <vector>
#include <string>
#include <fstream>
#include <iostream>
#include <stdexcept>

#include "terminal_graphics.h"

#include "debug.h"
#include "dataset.h"
#include "image.h"
#include "pgm.h"
#include "utils.h"



// This function contains our program's core functionality:

void run (std::vector<std::string>& args) {
    debug::verbose = std::erase(args, "-v");

    // Valid input check
    if (args.size() < 3) {
        throw std::runtime_error ("missing arguments - expected at least 2 arguments: taskfile followed by list of images");
    }

    // Allow the user to specify the centre of the mask and the size of the mask for different LVBP regions
    // Defaulted to (74,90) and 5x5 mask for the example image
    int centreX = 74, centreY = 90, maskSize = 5;
    auto pixel_option = std::ranges::find (args, "-p");
    if (pixel_option != args.end()) {
        if (std::distance (pixel_option, args.end()) < 3)
            throw std::runtime_error ("not enough arguments to '-p' option (expected '-p x y')");
        centreX = std::stoi (*(pixel_option+1));
        centreY = std::stoi (*(pixel_option+2));
        maskSize = std::stoi (*(pixel_option+3));
    args.erase (pixel_option, pixel_option+4);
    
  }
    // 1: Load in a time series image using Dataset
    Dataset<int> data ({ args.begin()+2, args.end() });

    // 2: Load in the "constrast.info" file 
    ContrastAgent agent = load_contrast_info(args[1]);

    // 3: Create a 2D binary image mask
    BinaryImage binary_image (data[0]); // Create the binary mask with (any) image instance
    binary_image.applyMask(centreX, centreY, maskSize); // set the centre of the mask and the mask size

    debug::log(std::format("Binary mask of size {}x{} has been created", binary_image.width(), binary_image.height()));


    // 4: Calculate the average signal S(d) in the LVBP region for each time frame d, and plot this timecourse on the terminal.
    //double average_signal;

    std::vector<double> average_signal = compute_average_signal(data.m_slices, binary_image, centreX, centreY, maskSize);
   
    std::cout << "Signal timecourse within ROI: \n";
    TG::plot(1000, 400)
        .add_line(average_signal);
 
        
    // 5: Identify the time frame of peak contrast concentration (dpeakBlood) 
    auto peak_conc = std::max_element(average_signal.begin(), average_signal.end());
    int d_peakBlood = std::distance(average_signal.begin(), peak_conc);
    double S_peakBlood = average_signal[d_peakBlood];
    std::cout << "Image at peak contrast concentration:\n";
    
    
    TG::imshow(TG::magnify(data[d_peakBlood], 3), 0, 400); // Displays the image at peak contrast concentration

    // 6: Identify the time frame of contrast arrival and corresponding signal intensity in the LVBP region.

    std::vector<double> gradientOfsignal = signal_gradient(average_signal);

    debug::log(std::format("Signal gradient timecourse: {} values \n", gradientOfsignal.size())); // 19 values
    debug::log(std::format("Average gradient timecourse: {} values \n", average_signal.size())); // 20 values

        // Find the first time frame where the gradient exceeds 10
    int d_arrival = 1;
    for (auto grad : gradientOfsignal) {
        if (grad > 10) {
            break;
        } else {
            ++d_arrival;
        }
    }
    double S_arrival = average_signal[d_arrival];
    std::cout << "Gradient of signal timecourese within ROI:\n";
    TG::plot(1000, 400)
        .add_line(gradientOfsignal, 3);

    // 7: Compute the remporal gradient of the signal timecourse
    double G = temporal_gradient(S_peakBlood, S_arrival, d_peakBlood, d_arrival);

    // 8:Display the contrast agent info of scan and other metrics
    std::cout << "Contrast agent: " << agent.agent_name << ", Dose: " << agent.dose << "\n";
    std::cout << "Contrast arrival occurs at frame " << d_arrival << " with signal intensity: " << S_arrival << "\n";
    std::cout << "Peak contrast concentration occurs at frame " << d_peakBlood <<  " with signal intensity: " <<  S_peakBlood << "\n";
    std::cout << "Temporal gradient of signal during contrast update: " << G << "\n";
}


// skeleton main() function, whose purpose is now to pass the arguments to
// run() in the expected format, and catch and handle any exceptions that may
// be thrown.

int main (int argc, char* argv[])
{
    try {
        std::vector<std::string> args (argv, argv+argc);
        run(args);
    }
    catch (std::exception& excp) {
        std::cerr << "ERROR: " << excp.what() << " - aborting\n";
        return 1;
    }
    catch (...) {
        std::cerr << "ERROR: unknown exception thrown - aborting\n";
        return 1;
    }

    return 0;
}
