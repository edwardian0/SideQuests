#pragma once

#include <iostream>
#include <string>
#include <format>

namespace debug {
    extern bool verbose;
    inline bool verbose = false;

    inline void log (const std::string& message) {
        if (verbose)
        std::cerr << "[DEBUG] " << message << "\n";
    }
}
