#pragma once

#include <vector>
#include <string>
#include <format>

#include "image.h"
#include "pgm.h"
#include "debug.h"

// Class to store the series of images in one object
// This class is a wrapper around the Image class, and is can be used to load in a series of images
template <typename ValueType>
class Dataset
{
  public:
    Dataset () = default;
    // Overloaded constructor to load in the series of images
    Dataset (const std::vector<std::string>& filenames) { load (filenames); }

    // Member function to load in a series of images
    void load (const std::vector<std::string>& filenames);
    // Member function to return the number of images in the dataset
    unsigned int size () const { return m_slices.size(); }

    // Overloaded operator to access the images in the dataset
    Image<ValueType>&       operator[] (int n)       { return m_slices[n]; }
    const Image<ValueType>& operator[] (int n) const { return m_slices[n]; }

    // Member function to return the timecourse of a pixel in the dataset
    std::vector<ValueType> get_timecourse (int x, int y) const;

    std::vector<Image<ValueType>> m_slices;
};


template <typename ValueType>
inline std::ostream& operator<< (std::ostream& out, const Dataset<ValueType>& data)
{
  out << "Data set with " << data.size() << " images:\n";
  for (unsigned int n = 0; n < data.size(); ++n)
    out << "  image " << n << ": " << data[n] << "\n";
  return out;
}

// Definition of member function to load in a series of images
template <typename ValueType>
void Dataset<ValueType>::load (const std::vector<std::string>& filenames)
{
  m_slices.clear();

  if (filenames.empty())
    throw std::runtime_error ("no filenames supplied when loading dataset");

  for (const auto& fname : filenames)
    m_slices.push_back (load_pgm (fname));

  // check that dimensions all match up:
  for (unsigned int n = 1; n < m_slices.size(); ++n) {
    if ( (m_slices[n].width() != m_slices[n-1].width()) ||
         (m_slices[n].height() != m_slices[n-1].height()) )
      throw std::runtime_error ("dimensions do not match across slices");
  }

  debug::log (std::format (
      "loaded {} slices of size {}x{}\n",
      m_slices.size(), m_slices[0].width(), m_slices[0].height()));
}





template <typename ValueType>
std::vector<ValueType> Dataset<ValueType>::get_timecourse (int x, int y) const
{
  std::vector<ValueType> vals (size());
  for (unsigned int n = 0; n < size(); ++n)
    vals[n] = m_slices[n](x,y);
  return vals;
}
