#pragma once

#include <string>

#include "image.h"

// Function dedicated to the loading of the pgm image files
Image<int> load_pgm (const std::string& filename);
