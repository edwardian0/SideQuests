#pragma once

#include <array>
#include <vector>
#include <iostream>
#include <stdexcept>

// Class to represent the image data from the pgm files
template <typename ValueType>
class Image {
  public:
    Image (int xdim, int ydim) :
      m_dim { xdim, ydim }, m_data (xdim*ydim, 0) { }

    Image (int xdim, int ydim, const std::vector<ValueType>& data) :
      m_dim {xdim, ydim }, m_data (data) {
        if (static_cast<int> (m_data.size()) != m_dim[0] * m_dim[1])
          throw std::runtime_error ("dimensions mismatch between image sizes and data vector");
      }

    // Getters for the width and heigth of the current instance of image
    int width () const { return m_dim[0]; }
    int height () const { return m_dim[1]; }

    const ValueType& operator() (int x, int y) const { return m_data[x + m_dim[0]*y]; }
    ValueType& operator() (int x, int y) { return m_data[x + m_dim[0]*y]; }


  private:
    std::array<int,2> m_dim;
    std::vector<ValueType> m_data;
};



template <class ValueType>
inline std::ostream& operator<< (std::ostream& out, const Image<ValueType>& im)
{
  out << "Image of size " << im.width() << "x" << im.height();
  return out;
}

// Class to create a binary image mask
// This class is a derived class of the Image class, and is used to create a binary image mask
class BinaryImage : public Image<int>
{    
    public:
        // Constructor that ensures same size as an existing image
        template <typename ValueType>
        BinaryImage(const Image<ValueType>& referenceImage)
            : Image<int>(referenceImage.width(), referenceImage.height()) {}

        // Member function to create the 5×5 mask at (centreX, centreY). 
        void applyMask(int centreX, int centreY, int maskSize = 5) {
            int halfSize = maskSize / 2;
            // Look at the point (centreX, centreY) region and set the values to 1 to obtain mask
            for (int y = centreY - halfSize; y <= centreY + halfSize; ++y) {
                for (int x = centreX - halfSize; x <= centreX + halfSize; ++x) {
                    if (x >= 0 && x < width() && y >= 0 && y < height()) {
                        // Set mask pixels at this location to 1, for this instance of Image
                        (*this)(x, y) = 1;
                    }
                }
            }
        }
};
