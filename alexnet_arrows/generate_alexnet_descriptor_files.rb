#!/usr/bin/ruby


# Based on other annotation scripts in here, this script
# generates the files necessary for creating mdb files
# to use with caffe.
#
# It looks for positives in positives/, and for
# negatives in negatives/, generating the
# appropriate txt files.
#
# It takes one argument:
#   1. The output folder for annotation files

require 'csv'
require 'fastimage'

NEG_FACTOR = 2.0

if ARGV.length < 1
  abort "Usage: #{$0} output_folder"
end

target_folder = ARGV[0].chomp('/')

# Read in list of images in positives folder
positive_images = Dir["positives/*"] # Could shuffle here, if desired
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

    # Get filename without folder prefix
    img_name = img_path.split('/').last#.split('.').tap{|parts| parts.pop}.join('.')

    if train_count < num_train # Write to train and trainval
      train_count += 1

      # Arrowhead files
      # Should condense this with a wrapper function
      File.open("#{target_folder}/train.txt", 'a') do |train_file|
        train_file.puts "#{img_name} 1"
      end
    elsif val_count < num_val # Write to val and trainval
      val_count += 1

      # Arrowhead files
      File.open("#{target_folder}/val.txt", 'a') do |val_file|
        val_file.puts "#{img_name} 1"
      end
    else # Write to test file
      test_count += 1

      # Arrowhead file
      File.open("#{target_folder}/test.txt", 'a') do |test_file|
        test_file.puts "#{img_name} 1"
      end
    end
  end
end

puts "Positive Training Count: #{train_count}"
puts "Positive Validation Count: #{val_count}"
puts "Positive Test Count: #{test_count}"

puts

negative_images = Dir["negatives/*"]
puts "Total Negative Images: #{negative_images.count}"

train_count = 0
val_count = 0
test_count = 0

negative_images.each do |img_path|
  size = FastImage.size(img_path)

  unless size.nil?
    img_name = img_path.split('/').last#.split('.').tap{|parts| parts.pop}.join('.')

    if train_count < NEG_FACTOR * num_train  # Write to train and trainval
      train_count += 1

      # Arrowhead files
      File.open("#{target_folder}/train.txt", 'a') do |train_file|
        train_file.puts "#{img_name} 0"
      end
    elsif val_count < NEG_FACTOR * num_val # Write to val and trainval
      val_count += 1

      # Arrowhead files
      File.open("#{target_folder}/val.txt", 'a') do |val_file|
        val_file.puts "#{img_name} 0"
      end
    else # Write to test file
      test_count += 1

      # Arrowhead file
      File.open("#{target_folder}/test.txt", 'a') do |test_file|
        test_file.puts "#{img_name} 0"
      end
    end
  end
end

puts "Negative Training Count: #{train_count}"
puts "Negative Validation Count: #{val_count}"
puts "Negative Test Count: #{test_count}"
