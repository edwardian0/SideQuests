#pragma once

#include "fragments.h"
#include <string>

class ShotgunSequencer {
  public:
    ShotgunSequencer(const std::vector<std::string>& fragments, int min_overlap = 10);
    bool iterate ();
    void check_remaining_fragments ();

    const std::vector<std::string>& remaining_fragments () const { return m_fragments; }
    const std::string& sequence () const { return m_sequence; }

  private:
    const int m_minimum_overlap;
    std::string m_sequence;
    std::vector<std::string> m_fragments;
    void init (const std::vector<std::string>& fragments);
    // CODE REFACTOR: Incorporated the following private, methods from overlap.h and overlap.cpp
    struct Overlap {
        int size;
        int fragment;
    };
    int compute_overlap (const std::string& sequence, const std::string& fragment);
    Overlap find_biggest_overlap (const std::string& sequence, std::vector<std::string>& fragments);
    void merge (std::string& sequence, const std::string& fragment, const int overlap); 
};
