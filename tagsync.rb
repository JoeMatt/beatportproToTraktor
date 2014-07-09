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

$options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: fixdates.rb [options]"

  opts.on('-s', '--searchdirectory NAME', 'Search directory') { |v| $options[:search_directory] = v }
#   opts.on('-r', '--[no-]recursive', 'Recursive search') { |v| options[:search_recursive] = v }
  opts.on('-d', '--dump file', 'Dump ID3 tags of file') { |v| $options[:dump_file] = v }

  $options[:quiet] = false
  opts.on('-q', '--quiet', 'Be quiet') do $options[:quiet] = true end

  $options[:clean_comments] = false
  opts.on('-c', '--cleancomments', 'String keys from comments') do $options[:clean_comments] = true end

  $options[:release_only] = false
  opts.on('-r', '--releaseonly', 'Only update release tags') do $options[:release_only] = true end
  
  $options[:key_only] = false
  opts.on('-k', '--keyonly', 'Only update key tags') do $options[:key_only] = true end

  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
end

optparse.parse!

    #dump all non-nil valued frames
def dumpFrames(tag)
  puts "id3v2.#{tag.header.major_version}.#{tag.header.revision_number} #{tag.header.tag_size} bytes"

  tag.frame_list.each do |frame|
    unless frame.to_string.nil?
      print(frame.frame_id + "\t"+  frame.to_string + "\n") 
    else
      if frame.is_a? TagLib::ID3v2::UniqueFileIdentifierFrame
        print(frame.frame_id + "\t" + frame.identifier() + "\n") 
      end
    end
  end
end

# TODO :: simplify code duplication : fromFrame needs to be array of options
def copyFrameToFrame(tag, fromFrame, toFrame)
end

def cleanKeyCodesFromComments(tag)
  # substrings to strip
  codes = [ "01A", "1A", "01B", "1B",
            "02A", "2A", "02B", "2B",
            "03A", "3A", "03B", "3B",
            "04A", "4A", "04B", "4B",
            "05A", "5A", "05B", "5B",
            "06A", "6A", "06B", "6B",
            "07A", "7A", "07B", "7B",
            "08A", "8A", "08B", "8B",
            "09A", "9A", "09B", "9B",
            "10A", "10B",
            "11A", "11B",
            "12A", "12B", " -"]

  comment_frame = tag.frame_list('COMM').first

  unless comment_frame == nil

    #get the string value
    string = comment_frame.text

    unless $options[:quiet]
      puts "\tComment: #{string}"      
    end

    modded = false
    #strip any subs trings in code array
    codes.each do |s|
      result  = string.slice!(s)
      if result != nil then modded = true end
    end

    #update tag
    if modded == true then 
      # strip leading/trailing white space that may now exist
      string.rstrip!
      string.lstrip!

      if string === nil or string.length == 0
        unless $options[:quiet]
          puts "\tDeleting comment"
          tag.remove_frame(comment_frame)
        end
      else
        comment_frame.text = string 
        unless $options[:quiet]
          puts "\tNew comment: #{tag.frame_list('COMM').first}"
        end
      end


    end

    return modded
  else
    return "No comments tag"
  end
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
      unless $options[:quiet] then printf("TDRC Frame is nil. Creating new") end
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
        printf("\tUpdating realase date to " + tag.frame_list('TDRC').first.to_s + "\n")        
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
        puts "\tUpdating key to #{tag.frame_list('TKEY').first.to_s}."        
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

    unless $options[:quiet]
      filename = File.basename(path, '.*')
      printf("~ %s \n", filename)      
    end

    commentsUpdated = dateUpdated = keyUpdated = false

    unless $options[:key_only]
      dateUpdated = copyBeatportDateToTDRC(tag)      
    end

    unless $options[:release_only]
      keyUpdated = copyBeatportKeyToKeyText(tag)      
    end

    if $options[:clean_comments]
      commentsUpdated = cleanKeyCodesFromComments(tag)
    end

    needToSave = (dateUpdated  === true or keyUpdated === true or commentsUpdated === true)

    if dateUpdated.is_a? String
      unless $options[:quiet]
        puts "\t" + dateUpdated        
      end
    end

    if keyUpdated.is_a? String
      unless $options[:quiet]
        puts "\t" + keyUpdated
      end
    end

    if commentsUpdated.is_a? String
      unless $options[:quiet]
        puts "\t" + commentsUpdated
      end
    else
      puts "\t" + (commentsUpdated ? "Comments cleaned" : "Comments didn't contain codes")
    end

    if needToSave
      file.save(TagLib::MPEG::File::ID3v2, false) #false prevents id3v1 stripping 
      unless $options[:quiet]
        puts "\tSaved."       
      end
      return 1
    end
  end  # File is automatically closed at block end
  return 0
end

def main

# TODO support list of ARGV files and folders
#  ARGV.each do|f|
#   # process directory or file 
#   sleep 0.5
#  end

  searchDirectory = "."
  unless $options[:search_directory] === nil
    searchDirectory = $options[:search_directory]
  end
  mp3FilePaths = []

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
      counter = 0
      mp3FilePaths.each{|path|
        fileModded = updateFileAtPath(path)
        counter += fileModded
      }
      printf("%i files updated.", counter)      
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
