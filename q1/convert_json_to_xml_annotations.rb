#!/usr/bin/ruby

# This script handles converting hand annotations in json into the
# appropriate XML and txt file formats for training with a dpm with
# http://www.cs.berkeley.edu/~rbg/latent/
#
# It looks for annotations in annotations.json, and the images in
# images/. All images (including ones lacking positives) should be
# in images/, as the script generates negative annotations for images
# not recorded in annotations.json.
#
# It takes one argument:
#   1. The output folder in which to store the annotation files (must exist)

require 'json'
require 'fastimage'

if ARGV.length < 1
  abort "Usage: #{$0} output_folder"
end

target_folder = ARGV[0].chomp('/')

annotations = JSON.parse(File.read('annotations.json'))

annotations.each do |img_path, labels|
  size = FastImage.size("images/#{img_path}")

  unless size.nil?

    File.open("#{target_folder}/#{img_path}.xml", 'w') do |file|
      file.puts "<annotation>\n\t<filename>#{img_path}.jpg</filename>\n\t<folder>VOC2020</folder>\n"

      width = size[0]
      height = size[1]

      labels.each do |label|
        xmin = label['bounds']['coords'][0]['x']
        ymin = label['bounds']['coords'][0]['y']

        xmax = label['bounds']['coords'][1]['x']
        ymax = label['bounds']['coords'][1]['y']

        file.puts "\t<object>"
        file.puts "\t\t<name>arrowhead</name>\n\t\t<bndbox>\n\t\t\t<xmax>#{xmax}</xmax>\n\t\t\t<xmin>#{xmin}</xmin>"
        file.puts "\t\t\t<ymax>#{ymax}</ymax>\n\t\t\t<ymin>#{ymin}</ymin>\n\t\t</bndbox>\n\t\t<difficult>0</difficult>"
        file.puts "\t\t<occluded>0</occluded>\n\t\t<pose>Unspecified</pose>\n\t\t<truncated>0</truncated>\n\t</object>"
      end

      file.puts "\t<segmented>0</segmented>\n\t<size>\n\t\t<depth>3</depth>\n\t\t<height>#{height}</height>"
      file.puts "\t\t<width>#{width}</width>\n\t</size>\n\t<source>\n\t\t<annotation>Nick Reiter</annotation>"
      file.puts "\t\t<database>UW CSE</database>\n\t\t<image>q1 targets</image>\n\t</source>\n</annotation>"
    end

    # Arrowhead file
    File.open("#{target_folder}/arrowhead_test.txt", 'a') do |test_file|
      test_file.puts "#{img_path} 1"
    end

    # Aggregate file
    File.open("#{target_folder}/test.txt", 'a') do |test_file|
      test_file.puts "#{img_path}"
    end
  end
end

negatives = Dir['images/*'].map do |path|
  path.split('/').last
end.delete_if do |img|
  annotations.key? img
end

negatives.each do |img_path|
  size = FastImage.size("images/#{img_path}")

  unless size.nil?

    File.open("#{target_folder}/#{img_path}.xml", 'w') do |file|
      file.puts "<annotation>\n\t<filename>#{img_path}.jpg</filename>\n\t<folder>VOC2020</folder>\n"

      width = size[0]
      height = size[1]

      xmin = ymin = 0

      xmax = width
      ymax = height

      file.puts "\t<object>"
      file.puts "\t\t<name>background</name>\n\t\t<bndbox>\n\t\t\t<xmax>#{xmax}</xmax>\n\t\t\t<xmin>#{xmin}</xmin>"
      file.puts "\t\t\t<ymax>#{ymax}</ymax>\n\t\t\t<ymin>#{ymin}</ymin>\n\t\t</bndbox>\n\t\t<difficult>0</difficult>"
      file.puts "\t\t<occluded>0</occluded>\n\t\t<pose>Unspecified</pose>\n\t\t<truncated>0</truncated>\n\t</object>"

      file.puts "\t<segmented>0</segmented>\n\t<size>\n\t\t<depth>3</depth>\n\t\t<height>#{height}</height>"
      file.puts "\t\t<width>#{width}</width>\n\t</size>\n\t<source>\n\t\t<annotation>Nick Reiter</annotation>"
      file.puts "\t\t<database>UW CSE</database>\n\t\t<image>q1 targets</image>\n\t</source>\n</annotation>"
    end

    # Arrowhead file
    File.open("#{target_folder}/arrowhead_test.txt", 'a') do |test_file|
      test_file.puts "#{img_path} -1"
    end

    # Aggregate file
    File.open("#{target_folder}/test.txt", 'a') do |test_file|
      test_file.puts "#{img_path}"
    end
  end
end
