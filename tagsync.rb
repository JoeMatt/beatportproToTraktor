#!/usr/local/opt/ruby/bin/ruby

# use tablib based on the C++ library api doc: http://taglib.github.io/api/
require 'taglib'
# find the mp3s
require 'find'
# commandline flags
require 'optparse'
require 'io/console'

#set to true for verbose messages
$debug = false

$counter = 0
$options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: fixdates.rb [options]"

  opts.on('-s', '--searchdirectory NAME', 'Search directory') { |v| $options[:search_directory] = v }
#   opts.on('-r', '--[no-]recursive', 'Recursive search') { |v| options[:search_recursive] = v }
  opts.on('-d', '--dump file', 'Dump ID3 tags of file') { |v| $options[:dump_file] = v }
  opts.on('-q', '--quiet', 'Be quiet') {|v| $options[:quiet] = v}

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

    #dump all non-nil valued frames
def dumpFrames(tag)
  tag.frame_list.each do |frame|
    unless frame.to_string.nil?
      print(frame.frame_id + "\t"+  frame.to_string + "\n")      
    end
  end
end

# TODO :: simplify code duplication : fromFrame needs to be array of options
def copyFrameToFrame(tag, fromFrame, toFrame)
end

# Parameter tag => TagLib::ID3v2
# return  true => Tag was updated
#         string => Error why the tag couldn't or needn't be updated
def copyBeatportDateToTDRC(tag)
  # Get beatport pro's tagged release date
  # Try TDRL frame first
  beatportDate = tag.frame_list('TDRL').first
  if beatportDate.to_s.nil?
    # if nil for some reason, try TDOR frame.
    # Beatport pro seems to set both
    beatportDate = tag.frame_list('TDOR').first
  end

  # Check we were able to get a valid value
  if beatportDate != nil && beatportDate.to_s != ""

    if $debug then puts "Current TDRC: " +tag.frame_list('TDRC').first.to_s end
    tdrc_frame = tag.frame_list('TDRC').first

    if tdrc_frame == nil
      printf("TDRC Frame is nil. Creating new")
      # Have to add the frame then get it. Adding it seems to destroy the object
      tag.add_frame(TagLib::ID3v2::TextIdentificationFrame.new("TDRC", TagLib::String::UTF8))
      # Get the referene to the new frame
      tdrc_frame = tag.frame_list('TDRC').first
    end

    # Check that they're not already ==
    if tdrc_frame.to_s == beatportDate.to_s
      return "Date already correct"
    else
      tdrc_frame.text = beatportDate.to_s

      unless $options[:quiet]
        printf("Updating to " + tag.frame_list('TDRC').first.to_s + " ...")        
      end
      # return true that we've updated the frame
      return true
    end 
  else
    return  "No date value to use"
  end
end

# Parameter tag => TagLib::ID3v2
# return  true => Tag was updated
#         string => Error why the tag couldn't or needn't be updated
def copyBeatportKeyToKeyText(tag)
  keyFrame = tag.frame_list('TKY2').first

  if keyFrame === nil
    return "No key value to use"
  else
    keyTextFrame = tag.frame_list('TKEY').first

    #create key text frame if necessary
    if keyTextFrame === nil
      unless $options[:quiet]
        printf("TKEY Frame is nil. Creating new")        
      end
      # Have to add the frame then get it. Adding it seems to destroy the object
      tag.add_frame(TagLib::ID3v2::TextIdentificationFrame.new("TKEY", TagLib::String::UTF8))
      # Get the referene to the new frame
      keyTextFrame = tag.frame_list('TKEY').first
    end

  # Check that they're not already ==
    if keyTextFrame.to_s == keyFrame.to_s
      return "Key already correct"
    else
      keyTextFrame.text = keyFrame.to_s

      unless $options[:quiet]
        printf("Updating to " + tag.frame_list('TKEY').first.to_s + " ...")        
      end
      # return true that we've updated the frame
      return true
    end 

  end
end

##
# Write key and/or releae date tags
def updateFileAtPath(path)
  # Load an ID3v2 tag from a file
  TagLib::MPEG::File.open(path) do |file|
    # get the tag object
    tag = file.id3v2_tag

    if $debug then dumpFrames(tag) end

    unless $options[:quiet]
      filename = File.basename(path, '.*')
      printf("~ %s \n", filename)      
    end

    dateUpdated = copyBeatportDateToTDRC(tag)
    keyUpdated = copyBeatportKeyToKeyText(tag)

    needToSave = dateUpdated  === true or keyUpdated === true

    if dateUpdated != true
      unless $options[:quiet]
        puts "\t" + dateUpdated        
      end
    end

    if keyUpdated != true
      unless $options[:quiet]
        puts "\t" + keyUpdated
      end
    end

    if needToSave
      file.save(TagLib::MPEG::File::ID3v2, false) #false prevents id3v1 stripping 
      unless $options[:quiet]
        printf(" Done.\n")       
      end
      $counter = $counter + 1
    end

  end  # File is automatically closed at block end
end

def main
  searchDirectory = "."
  unless $options[:search_directory] === nil
    searchDirectory = $options[:search_directory]
  end
  mp3FilePaths = []
  # Find.find('./') do |path|
  #   mp3FilePath << path if path =~ /.*\.mp3$/
  # end
  unless $options[:quiet]
    puts "Searching for mp3's ..."
  end
  
  mp3FilePaths = Dir.glob("#{searchDirectory}/**/*.mp3")

  #interactive mode, prompts user to continue after finding mp3's
  unless $options[:quiet]
    puts "#{mp3FilePaths.length} files to process. Continue? [y/n]"

    begin
      input = STDIN.getch.downcase
    end while (input != 'y' && input != 'n')

    unless input == 'n'
      mp3FilePaths.each{|path| updateFileAtPath(path)}
      printf("%i files updated.", $counter)      
    end
    #non-interactive. Just continue
  else 
    mp3FilePaths.each{|path| updateFileAtPath(path)}
  end

end

#call main
if $options[:dump_file]
    TagLib::MPEG::File.open($options[:dump_file]) do |file|
      # get the tag object
      tag = file.id3v2_tag
      dumpFrames(tag)
    end
else
  main()
end
