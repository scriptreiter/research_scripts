#!/usr/bin/ruby

# This is a short script to take a directory of source images,
# and rotate them such that a specified number of rotated versions
# are produced for each individual source image.
#
# It looks for source images in source/, which should be a crop
# to the bounding box for a given positive.
#
# It stores the images in generated/
#
# These paths are configurable.
#
# It requires ImageMagick to be installed, on top of RMagick.

require 'rmagick'
include Magick

NUM_POSITIONS = 90
DEGREES = 360

image_paths = Dir['source/*']

# Could do this 1 by 1 if memory issues
images = image_paths.map {|path| Image.read(path).first}

NUM_POSITIONS.times do |i|
  rotation_amount = DEGREES * i * 1.0 / NUM_POSITIONS

  images.each do |img|
    img.rotate(rotation_amount).write(
      img.filename.gsub(/source\/(.*)\.jpg/, "generated/\\1_#{rotation_amount}.jpg")
    )
  end
end
