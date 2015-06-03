#!/usr/bin/ruby
#
# This script takes in results from our Amazon Mechanical Turk experiment,
# and outputs XML annotation files in the format of the PASCAL VOC dataset.
#
# It also produces the appropriate txt files describing the training and
# validation sets, which it chooses based on counts in the constants at
# the top.
#
# It attempts to deduplicate the results, by finding closely matching
# annotations, as we had three users annotate each image. It will attempt
# to merge annotations based on a configurable percent overlap.
#
# These files can be used to train a deformable parts model, using the code
# from http://www.cs.berkeley.edu/~rbg/latent/.
#
# It takes two arguments:
#   1. The path to the csv file (see arrows.csv in mechanical_turk/)
#   2. An output folder to store the annotation files in (must already exist)
#
#   It assumes that images are hosted at the url seen in the code below,
#   except for some negative images, which should be in `negative_jpegs/`
#
#   These paths are modifiable.

require 'csv'
require 'fastimage'

if ARGV.length < 2
  abort "Usage: #{$0} csv_file target_folder"
end

NUM_TRAIN = 520
NUM_VAL = 520
NUM_TEST = 110
OVERLAP_THRESHOLD = 0.3

def find_max_arrow(arrow_1, arrows)
  max_i = -1
  max_o = 0

  arrows.each_with_index do |arrow_2, i|
    overlap = arrow_overlap(arrow_1, arrow_2)

    if(overlap > max_o)
      max_o = overlap
      max_i = i
    end
  end

  return [max_i, max_o]
end

# Calculates intersection / union of areas
def arrow_overlap(arrow_1, arrow_2)
  head_1 = arrow_1[:head]
  head_2 = arrow_2[:head]
  overlap_x = [[head_1[:xmax], head_2[:xmax]].min - [head_1[:xmin], head_2[:xmin]].max, 0].max
  overlap_y = [[head_1[:ymax], head_2[:ymax]].min - [head_1[:ymin], head_2[:ymin]].max, 0].max

  intersection = overlap_x * overlap_y

  area_1 = (head_1[:xmax] - head_1[:xmin]) * (head_1[:ymax] - head_1[:ymin])
  area_2 = (head_2[:xmax] - head_2[:xmin]) * (head_2[:ymax] - head_2[:ymin])

  union = area_1 + area_2 - intersection

  intersection * 1.0 / union
end

csv_file = ARGV[0]
target_folder = ARGV[1].chomp('/')

data = CSV.new(File.read(csv_file), { :headers => :first_row, :header_converters => :symbol })
results = {}

data.each do |row| # Go through each row of results
  image = row[:inputimage_url]

  results[image] ||= [] # We want to collect multiple results for the same image
  results[image].push([])

  row.each do |name, val|
    if name.to_s.start_with?('answerarrow_') && !val.empty? # If it is a non-blank arrow result
      arrow = {}
      arrow[:head] = {}
      #arrow[:tail] = {} # Don't need to do anything with tail info, yet

      # Split the result to extract information
      # (hr, hcx, hcy),(tr, tcx, tcy)
      parts = val.split('),(')
      h_r, h_cx, h_cy = parts[0][1..-1].split(',').map(&:to_f)
      #t_r, t_cx, t_cy = parts[1][0...-1].split(',')

      # Store the arrow info
      arrow[:head][:xmax] = (h_cx + h_r).ceil
      arrow[:head][:xmin] = (h_cx - h_r).floor

      arrow[:head][:ymax] = (h_cy + h_r).ceil
      arrow[:head][:ymin] = (h_cy - h_r).floor

      #arrow[:tail][:radius] = tail_parts[0].to_i # This may have been better as to_f...
      #arrow[:tail][:center_x] = tail_parts[1].to_i
      #arrow[:tail][:center_y] = tail_parts[2].to_i

      results[image].last.push(arrow)

    end
  end
end

# Now we need to de-duplicate positive arrows
#
# For now, I'm going to utilize a heuristic method, that probably biases
# towards arrows from A, but gives O(n^2) instead of O(n^3) with
# n = max(size(A), size(B), size(C))

results.each do |image, arrow_lists|
  valid_arrows = []
  start_list = 0

  while arrow_lists.length - start_list > 1
  # Go through first set of arrows
    arrow_lists[start_list].each do |arrow_1|
      max_info = []
      (arrow_lists.length - start_list - 1).times do |i|
        max_info.push(find_max_arrow(arrow_1, arrow_lists[i + start_list + 1]))
      end

      # Check if any of the overlaps is bigger than the threshold
      # If so, then need to add the intersection
      # Otherwise we don't need to do anything
      if max_info.map(&:last).max >= OVERLAP_THRESHOLD # Could combine this with the next line
        # This gets information about all the arrows that match the reference arrow,
        # and stores an array of matching arrow info, in the form of:
        # [index_of_annotator_arrow_list, index_within_annotator_arrow_list]
        agreeing_arrow_info = max_info.each_with_index.select{|info| info.first.last >= OVERLAP_THRESHOLD}.map{|info| [info.last + start_list + 1, info.first.first]}

        # This finds the intersecting arrow from all the agreeing arrows
        # It selects the minimum xmax and ymax, and the maximum xmin and ymin
        valid_arrows.push({
          :head => {
            :xmax => agreeing_arrow_info.map{|info| arrow_lists[info[0]][info[1]][:head][:xmax]}.min,
            :xmin => agreeing_arrow_info.map{|info| arrow_lists[info[0]][info[1]][:head][:xmin]}.max,
            :ymax => agreeing_arrow_info.map{|info| arrow_lists[info[0]][info[1]][:head][:ymax]}.min,
            :ymin => agreeing_arrow_info.map{|info| arrow_lists[info[0]][info[1]][:head][:ymin]}.max
          }
        })

        # Now we need to delete agreeing arrows from their lists, so we don't consider them for further matching
        agreeing_arrow_info.each{|info| arrow_lists[info[0]].delete_at(info[1])}
      end
    end

    # Now consider the next list
    start_list += 1
  end

  # Change the data structure to store the valid arrows, only
  results[image] = valid_arrows
end

# At this point we have a hash of image urls to lists of the arrows found in them

# Time to extract the ones with no arrows at all

# Because we have de-duped, we may want to not include these
# As the negatives selected here may have some arrows
# That were not duplicated, because of bad annotation
negatives = results.select {|k, v| v.empty? }.keys
positives = results.select {|k, v| !v.empty? }

puts 'Negative images:'
negatives.each do |url|
  puts url
end

puts
puts 'Positive images:'
total = 0
positives.each do |url, arrows| # Could do this with an inject
  puts "#{url}: #{arrows.length}"
  total += arrows.length
end

puts "Total Positive Arrow Boxes: #{total}\n"

# Create xml annotation file for each of these
# As well as label files

training_count = 0
validation_count = 0
test_count = 0

positives.each do |url, arrows|
  name = url.split('/').last
  full_url = "http://levan.cs.washington.edu/nick/arrows/processed/#{name}.jpg"
  size = FastImage.size(full_url)

  unless size.nil?
    num_arrows = arrows.count

    sanitized_name = name.gsub(/ /, '_')

    File.open("#{target_folder}/#{sanitized_name}.xml", 'w') do |file|
      file.puts "<annotation>\n\t<filename>#{name}.jpg</filename>\n\t<folder>VOC2020</folder>\n"

      width = size[0]
      height = size[1]

      arrows.each_with_index do |arrow, i|
        xmax = [arrow[:head][:xmax], width].min
        xmin = [arrow[:head][:xmin], 0].max

        ymax = [arrow[:head][:ymax], height].min
        ymin = [arrow[:head][:ymin], 0].max

        # Check if this is an invalid arrow
        # Arrows are invalid if off the canvas or
        # the bounding box has zero area
        if xmax <= xmin || ymax <= ymin
          num_arrows -= 1
          puts 'Rejecting one arrow'
          next
        end

        file.puts "\t<object>"
        file.puts "\t\t<name>arrowhead</name>\n\t\t<bndbox>\n\t\t\t<xmax>#{xmax}</xmax>\n\t\t\t<xmin>#{xmin}</xmin>"
        file.puts "\t\t\t<ymax>#{ymax}</ymax>\n\t\t\t<ymin>#{ymin}</ymin>\n\t\t</bndbox>\n\t\t<difficult>0</difficult>"
        file.puts "\t\t<occluded>0</occluded>\n\t\t<pose>Unspecified</pose>\n\t\t<truncated>0</truncated>\n\t</object>"
      end

      file.puts "\t<segmented>0</segmented>\n\t<size>\n\t\t<depth>3</depth>\n\t\t<height>#{height}</height>"
      file.puts "\t\t<width>#{width}</width>\n\t</size>\n\t<source>\n\t\t<annotation>Nick Reiter</annotation>"
      file.puts "\t\t<database>UW CSE</database>\n\t\t<image>google</image>\n\t</source>\n</annotation>"
    end

    if training_count < NUM_TRAIN # Write to train and trainval
      File.open("#{target_folder}/arrowhead_train.txt", 'a') do |train_file|
        train_file.puts "#{sanitized_name} 1"
        training_count += num_arrows
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{sanitized_name} 1"
      end
    elsif validation_count < NUM_VAL # Write to val and trainval
      File.open("#{target_folder}/arrowhead_val.txt", 'a') do |val_file|
        val_file.puts "#{sanitized_name} 1"
        validation_count += num_arrows
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{sanitized_name} 1"
      end
    elsif test_count < NUM_TEST # Write to test file
      File.open("#{target_folder}/arrowhead_test.txt", 'a') do |test_file|
        test_file.puts "#{sanitized_name} 1"
        test_count += num_arrows
      end
    end
  end
end

puts "Positive Training Count: #{training_count}"
puts "Positive Validation Count: #{validation_count}"
puts "Positive Test Count: #{test_count}"

# Need to list negatives in the imageset files

# Add more negative images from the negative_jpegs folder
negatives.concat(Dir['negative_jpegs/*'])

training_count = 0
validation_count = 0
test_count = 0

negatives.each do |url|
  name = url.split('/').last

  if url.start_with? 'negative_jpegs' # Local image
    full_url = url
    name = name.split('.').tap{|arr| arr.pop}.join('.')
  else # Stored on server
    full_url = "http://levan.cs.washington.edu/nick/arrows/processed/#{name}.jpg"
  end

  size = FastImage.size(url)

  unless size.nil?
    num_arrows = (size[0] * size[1] / 10000) + 1

    sanitized_name = name.gsub(/ /, '_')

    if training_count < NUM_TRAIN # Write to train and trainval
      File.open("#{target_folder}/arrowhead_train.txt", 'a') do |train_file|
        train_file.puts "#{sanitized_name} -1"
        training_count += num_arrows
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{sanitized_name} -1"
      end
    elsif validation_count < NUM_VAL # Write to val and trainval
      File.open("#{target_folder}/arrowhead_val.txt", 'a') do |val_file|
        val_file.puts "#{sanitized_name} -1"
        validation_count += num_arrows
      end

      File.open("#{target_folder}/arrowhead_trainval.txt", 'a') do |trainval_file|
        trainval_file.puts "#{sanitized_name} -1"
      end
    elsif test_count < NUM_TEST # Write to test file
      File.open("#{target_folder}/arrowhead_test.txt", 'a') do |test_file|
        test_file.puts "#{sanitized_name} -1"
        test_count += num_arrows
      end
    end

    File.open("#{target_folder}/#{sanitized_name}.xml", 'w') do |file|
      file.puts "<annotation>\n\t<filename>#{name}.jpg</filename>\n\t<folder>VOC2020</folder>\n"

      width = size[0]
      height = size[1]

      num_arrows.times do |i|

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
      file.puts "\t\t<database>UW CSE</database>\n\t\t<image>google</image>\n\t</source>\n</annotation>"
    end
  end
end

puts "Negative Training Count: #{training_count}"
puts "Negative Validation Count: #{validation_count}"
puts "Negative Test Count: #{test_count}"
