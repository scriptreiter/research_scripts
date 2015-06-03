#!/usr/bin/ruby

# This script pulls out the random patch generation code
# from some of the other annotation scripts, and uses it
# to generate 256x256px negative images for training
# with caffe.
#
# It looks for large negative in negative_base/, and
# generates patches randomly from within
#
# It relies on having the imagemagick `convert` utility
# for the cropping.
#
# It stores the resulting patches in negatives.
#
# The number of patches to generate is hard coded, but
# can easily be changed.

require 'fastimage'

negative_images = Dir["negative_base/*"]

# Calculate number of patches needed per negative image
num_patches = (4590 * 2.0 / negative_images.count).ceil

negative_images.each_with_index do |img_path, i|
  size = FastImage.size(img_path)

  unless size.nil?
    width = size[0]
    height = size[1]

    # Generate 150x150 bounding boxes
    img_size = 256
    num_patches.times do |j|
      xmax = [Random.rand([width - img_size, 1].max) + img_size, width].min
      xmin = [xmax - img_size, 0].max

      ymax = [Random.rand([height - img_size, 1].max) + img_size, height].min
      ymin = [ymax - img_size, 0].max

      `convert "#{img_path}" -crop '#{xmax - xmin}x#{ymax - ymin}+#{xmin}+#{ymin}' "negatives/#{i}_#{j}_neg.jpg"`
    end
  end
end
