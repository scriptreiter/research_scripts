#!/usr/bin/ruby

# This script reads results from our Amazon Mechanical Turk setup,
# and outputs an html file showing the annotations, for basic inspection.
#
# It takes takes two arguments:
#   1. The path to a csv file of results downloaded from the amazon mechanical turk setup.
#      See the batch 1 results in arrows.csv
#   2. An output file
#
#   It assumes the images are hosted on http://levan.cs.washington.edu,
#   but that is easily modifiable to a local path, or other url
#
#   It requires styles.css for some formatting
#

require 'csv'

if ARGV.length < 2
  abort "Usage: #{$0} csv_file html_file"
end

csv_file = ARGV[0]
html_file = ARGV[1]

data = CSV.new(File.read(csv_file), { :headers => :first_row, :header_converters => :symbol })

File.open(html_file, 'w') do |file|

  file.puts '<html><head><title>Arrow Results</title>'
  file.puts '<link rel="stylesheet" type="text/css" href="styles.css" /></head><body>'

  data.each do |row|

    file.puts '<div class="image_result">'
    file.puts '<img src="'
    file.puts "http://levan.cs.washington.edu/nick/arrows/batches/#{row[:inputimage_url]}"
    file.puts '" /><svg>'

    row.each do |name, val|
      if name.to_s.start_with?('answerarrow_') && !val.empty?
        parts = val.split('),(')
        head_parts = parts[0][1..-1].split(',')
        tail_parts = parts[1][0...-1].split(',')

        file.puts "<circle r=\"#{head_parts[0]}\" cx=\"#{head_parts[1]}\" cy=\"#{head_parts[2]}\" />"
        file.puts "<circle r=\"#{tail_parts[0]}\" cx=\"#{tail_parts[1]}\" cy=\"#{tail_parts[2]}\" />"
      end
    end

    file.puts '</svg></div>'

  end

  file.puts '</body></html>'
end
