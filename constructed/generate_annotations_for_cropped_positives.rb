#!/usr/bin/ruby


# This script is very similar to the other annotation script. It generates
# the appropriate XML and txt files in the PASCAL VOC format for use with
# the dpm training code at http://www.cs.berkeley.edu/~rbg/latent/.
#
# It looks for positive images in learning_set/, which should be a close
# crop to the bounding box.
#
# It looks for negative images in negative_set/, and generates
# annotations for multiple 150x150px boxes randomly distributed
# in the images.
#
# It takes one argument:
#   1. The output folder in which to store annotations

require 'csv'
require 'fastimage'

NEG_FACTOR = 2.0

if ARGV.length < 1
  abort "Usage: #{$0} output_folder"
end

target_folder = ARGV[0].chomp('/')

positive_images = Dir["learning_set/*"]
puts "Total Positive Arrows: #{positive_images.count}\n"

num_train = num_val = (positive_images.count * 0.45).floor

# Create xml annotation file for each of these
# As well as label files

train_count = 0
val_count = 0
test_count = 0

positive_images.each do |img_path|
  size = FastImage.size(img_path)

  unless size.nil?

    # Get filename without folder prefix or extension
    img_name = img_path.split('/').last.split('.').tap{|parts| parts.pop}.join('.')

    File.open("#{target_folder}/#{img_name}.xml", 'w') do |file|
      file.puts "<annotation>\n\t<filename>#{img_name}.jpg</filename>\n\t<folder>VOC2020</folder>\n"

      width = size[0]
      height = size[1]

      # The entire image is taken to be the bounding box
      # for these patches
      xmin = ymin = 0
      xmax = width
      ymax = height

      file.puts "\t<object>"
      file.puts "\t\t<name>arrowhead</name>\n\t\t<bndbox>\n\t\t\t<xmax>#{xmax}</xmax>\n\t\t\t<xmin>#{xmin}</xmin>"
      file.puts "\t\t\t<ymax>#{ymax}</ymax>\n\t\t\t<ymin>#{ymin}</ymin>\n\t\t</bndbox>\n\t\t<difficult>0</difficult>"
      file.puts "\t\t<occluded>0</occluded>\n\t\t<pose>Unspecified</pose>\n\t\t<truncated>0</truncated>\n\t</object>"

      file.puts "\t<segmented>0</segmented>\n\t<size>\n\t\t<depth>3</depth>\n\t\t<height>#{height}</height>"
      file.puts "\t\t<width>#{width}</width>\n\t</size>\n\t<source>\n\t\t<annotation>Nick Reiter</annotation>"
      file.puts "\t\t<database>UW CSE</database>\n\t\t<image>pptx</image>\n\t</source>\n</annotation>"
    end

    if train_count < num_train # Write to train and trainval
      train_count += 1

      # Arrowhead files
      # Should condense this with a wrapper function
      File.open("#{target_folder}/arrowhead_train.txt", 'a') do |train_file|
        train_file.puts "#{img_name} 1"
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name} 1"
      end

      # Aggregate files
      File.open("#{target_folder}/train.txt", 'a') do |train_file|
        train_file.puts "#{img_name}"
      end

      File.open("#{target_folder}/trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name}"
      end
    elsif val_count < num_val # Write to val and trainval
      val_count += 1

      # Arrowhead files
      File.open("#{target_folder}/arrowhead_val.txt", 'a') do |val_file|
        val_file.puts "#{img_name} 1"
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name} 1"
      end

      # Aggregate files
      File.open("#{target_folder}/val.txt", 'a') do |val_file|
        val_file.puts "#{img_name}"
      end

      File.open("#{target_folder}/trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name}"
      end
    else # Write to test file
      test_count += 1

      # Arrowhead file
      File.open("#{target_folder}/arrowhead_test.txt", 'a') do |test_file|
        test_file.puts "#{img_name} 1"
      end

      # Aggregate file
      File.open("#{target_folder}/test.txt", 'a') do |test_file|
        test_file.puts "#{img_name}"
      end
    end
  end
end

puts "Positive Training Count: #{train_count}"
puts "Positive Validation Count: #{val_count}"
puts "Positive Test Count: #{test_count}"

puts

negative_images = Dir["negative_set/*"]
puts "Total Negative Images: #{negative_images.count}"

# Calculate number of patches needed per negative image
num_patches = (positive_images.count * NEG_FACTOR / negative_images.count).ceil

train_count = 0
val_count = 0
test_count = 0

negative_images.each do |img_path|
  size = FastImage.size(img_path)

  unless size.nil?
    img_name = img_path.split('/').last.split('.').tap{|parts| parts.pop}.join('.')

    if train_count < NEG_FACTOR * num_train  # Write to train and trainval
      train_count += num_patches

      # Arrowhead files
      File.open("#{target_folder}/arrowhead_train.txt", 'a') do |train_file|
        train_file.puts "#{img_name} -1"
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name} -1"
      end

      # Aggregate files
      File.open("#{target_folder}/train.txt", 'a') do |train_file|
        train_file.puts "#{img_name}"
      end

      File.open("#{target_folder}/trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name}"
      end
    elsif val_count < NEG_FACTOR * num_val # Write to val and trainval
      val_count += num_patches

      # Arrowhead files
      File.open("#{target_folder}/arrowhead_val.txt", 'a') do |val_file|
        val_file.puts "#{img_name} -1"
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name} -1"
      end

      # Aggregate files
      File.open("#{target_folder}/val.txt", 'a') do |val_file|
        val_file.puts "#{img_name}"
      end

      File.open("#{target_folder}/trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{img_name}"
      end
    else # Write to test file
      test_count += num_patches

      # Arrowhead file
      File.open("#{target_folder}/arrowhead_test.txt", 'a') do |test_file|
        test_file.puts "#{img_name} -1"
      end

      # Aggregate file
      File.open("#{target_folder}/test.txt", 'a') do |test_file|
        test_file.puts "#{img_name}"
      end
    end

    File.open("#{target_folder}/#{img_name}.xml", 'w') do |file|
      file.puts "<annotation>\n\t<filename>#{img_name}.jpg</filename>\n\t<folder>VOC2020</folder>\n"

      width = size[0]
      height = size[1]

      # Generate 150x150 bounding boxes
      num_patches.times do |i|
        xmax = [Random.rand([width - 150, 1].max) + 150, width].min
        xmin = [xmax - 150, 0].max

        ymax = [Random.rand([height - 150, 1].max) + 150, height].min
        ymin = [ymax - 150, 0].max

        file.puts "\t<object>"
        file.puts "\t\t<name>background</name>\n\t\t<bndbox>\n\t\t\t<xmax>#{xmax}</xmax>\n\t\t\t<xmin>#{xmin}</xmin>"
        file.puts "\t\t\t<ymax>#{ymax}</ymax>\n\t\t\t<ymin>#{ymin}</ymin>\n\t\t</bndbox>\n\t\t<difficult>0</difficult>"
        file.puts "\t\t<occluded>0</occluded>\n\t\t<pose>Unspecified</pose>\n\t\t<truncated>0</truncated>\n\t</object>"

        # Generate patch image
        # `convert "#{full_url}" -crop '#{xmax - xmin}x#{ymax - ymin}+#{xmin}+#{ymin}' "negative_patches/#{i}_#{name}"`
      end

      file.puts "\t<segmented>0</segmented>\n\t<size>\n\t\t<depth>3</depth>\n\t\t<height>#{height}</height>"
      file.puts "\t\t<width>#{width}</width>\n\t</size>\n\t<source>\n\t\t<annotation>Nick Reiter</annotation>"
      file.puts "\t\t<database>UW CSE</database>\n\t\t<image>pptx</image>\n\t</source>\n</annotation>"
    end
  end
end

puts "Negative Training Count: #{train_count}"
puts "Negative Validation Count: #{val_count}"
puts "Negative Test Count: #{test_count}"
