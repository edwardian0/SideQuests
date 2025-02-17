#include <iostream>
#include <algorithm>
#include <format>

#include "fragments.h"
#include "shotgun_sequencer.h"
#include "debug.h"

ShotgunSequencer::ShotgunSequencer(const std::vector<std::string>& fragments, int min_overlap) :
    m_minimum_overlap(min_overlap),
    m_fragments(fragments)
{
    m_fragments = fragments;
    if (debug::verbose)
        fragment_statistics (m_fragments);
    m_sequence = extract_longest_fragment (m_fragments);
}


bool ShotgunSequencer::iterate ()
{
  debug::log ("---------------------------------------------------");
  debug::log("fragments left: " + std::to_string(m_fragments.size()));

  auto overlap = find_biggest_overlap (m_sequence, m_fragments);

  if (overlap.fragment < 0)
    return false;

  if (std::abs (overlap.size) < m_minimum_overlap)
    return false;

  debug::log("fragment with biggest overlap is at index " + std::to_string(overlap.fragment) + " overlap = " + std::to_string(overlap.size));


  merge (m_sequence, m_fragments[overlap.fragment], overlap.size);
  m_fragments.erase (m_fragments.begin() + overlap.fragment);

  return true;
}



void ShotgunSequencer::check_remaining_fragments ()
{
  debug::log (m_fragments.size() + " fragments remaining unmatched - checking whether already contained in sequence...");
  int num_unmatched = 0;
  for (auto& frag : m_fragments) {
    if (m_sequence.find (frag) == std::string::npos)
      ++num_unmatched;
  }

  if (num_unmatched)
    std::cerr << "WARNING: " << num_unmatched << " fragments remain unmatched!\n";
  else
    debug::log ("all remaining fragments matched OK");
}



int ShotgunSequencer::compute_overlap(const std::string& sequence, const std::string& fragment) {
     if (fragment.size() > sequence.size())
    throw std::runtime_error ("fragment size larger than current sequence - this shouldn't happen!");

  int largest_overlap = 0;

  // Start from the largest overlap, and decrease size of overlap at each
  // iteration. This guarantees we stop as soon as we find the largest overlap:
  for (int overlap = fragment.size(); overlap > 0; --overlap) {
    const auto seq_start = sequence.substr(0, overlap);
    const auto frag_end = fragment.substr(fragment.size()-overlap);
    if (seq_start == frag_end) {
      largest_overlap = overlap;
      break;
    }
  }

  // We are going to allow the overlap to be negative, in which case it would
  // be interpreted as corresponding to the overlap from the end of the
  // sequence:
  for (int overlap = fragment.size(); overlap > largest_overlap; --overlap) {
    const auto seq_end = sequence.substr(sequence.size() - overlap);
    const auto frag_start = fragment.substr(0, overlap);
    if (seq_end == frag_start) {
      largest_overlap = -overlap;
      break;
    }
  }

  return largest_overlap;
}


Overlap find_biggest_overlap (const std::string& sequence, std::vector<std::string>& fragments)
{
  int biggest_overlap = 0;
  int fragment_with_biggest_overlap = -1;
  for (unsigned int n = 0; n < fragments.size(); ++n) {
    const auto overlap = compute_overlap (sequence, fragments[n]);
    if (std::abs (biggest_overlap) < std::abs (overlap)) {
      biggest_overlap = overlap;
      fragment_with_biggest_overlap = n;
    }
  }

  return { biggest_overlap, fragment_with_biggest_overlap };
}



void ShotgunSequencer::merge(std::string& sequence, const std::string& fragment, const int overlap) {
    if (overlap < 0) {
    sequence += fragment.substr (-overlap);
  }
  else if (overlap > 0) {
    sequence = fragment.substr (0, fragment.size()-overlap) + sequence;
  }
}