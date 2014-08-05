#!/usr/bin/env ruby

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
  opts.banner = "Usage: tagsync.rb [options]"
  opts.separator ""
  opts.separator "Specific options:"

  opts.on('-s', '--searchdirectory NAME', 'Search directory') { |v| $options[:search_directory] = v }

  $options[:search_recursive] = true
  opts.on('-r', '--[no-]recursive', 'Recursive search. Default recursive.') { |v| $options[:search_recursive] = v }
  
  opts.on('-d', '--dump FILE', 'Dump ID3 tags of file') { |v| $options[:dump_file] = v }

  $options[:quiet] = false
  opts.on('-q', '--quiet', 'Be quiet') do $options[:quiet] = true end

  $options[:clean_comments] = false
  opts.on('-c', '--cleancomments', 'String keys from comments') do $options[:clean_comments] = true end

  $options[:release_only] = false
  opts.on('-r', '--releaseonly', 'Only update release tags') do $options[:release_only] = true end
  
  $options[:key_only] = false
  opts.on('-k', '--keyonly', 'Only update key tags') do $options[:key_only] = true end

  $options[:strip_v1] = false
  opts.on('-1', '--stripv1',  'Strip v1 id3 tags.',
                              'Only does this if v2 was updated') do $options[:strip_v1] = true end

  $options[:open_to_cam] = false
  opts.on('-m', '--openToCam', 'Convert Open Key field to Cam key') do $options[:open_to_cam] = true end

  $options[:cam_to_open] = false
  opts.on('-o', '--camToOpen', 'Convert Cam Key field to Open key') do $options[:cam_to_open] = true end

  $options[:published_to_year] = false
  opts.on('-p', '--publishedToYear', 'Set the YEAR value according to the year in the published date.',
                                      'If no published date, does nothing.') do $options[:published_to_year] = true end

  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end

  if ARGV.length == 0
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

def copyCommentsV2toV1(v2Tag, v1Tag)

  comment_frame = v2Tag.frame_list('COMM').first

  if comment_frame != nil and v1Tag.comment != nil and v1Tag.comment == comment_frame.text
    # already the same
    return false
  end

  if comment_frame === nil and v1Tag.comment != nil
    puts "\tDeleting v1 comment"
    v1Tag.comment = nil
    return true
  else
    unless comment_frame === nil or v1Tag.comment == comment_frame.text
      puts "\tCopying v2 comment to v1 comment"
      v1Tag.comment = comment_frame.text    
      return true      
    end
  end

  return false
end

def openToCamKey(v2Tag)
  openToKeyMap = {  "1d"  => "08B",  "1m" => "08A",
                    "2d"  => "09B",  "2m" => "09A",
                    "3d"  => "10B",  "3m" => "10A",
                    "4d"  => "11B",  "4m" => "11A",
                    "5d"  => "12B",  "5m" => "12A",
                    "6d"  => "01B",  "6m" => "01A",
                    "7d"  => "02B",  "7m" => "02A",
                    "8d"  => "03B",  "8m" => "03A",
                    "9d"  => "04B",  "9m" => "04A",
                    "10d" => "05B", "10m" => "05A",
                    "11d" => "06B", "11m" => "06A",
                    "12d" => "07B", "12m" => "07A" }

  return false
end

def camToOpenKey(v2Tag)
  openToKeyMap = {  "08B" =>  "1d",  "08A" =>  "1m",
                    "09B" =>  "2d",  "09A" =>  "2m",
                    "10B" =>  "3d",  "10A" =>  "3m",
                    "11B" =>  "4d",  "11A" =>  "4m",
                    "12B" =>  "5d",  "12A" =>  "5m",
                    "01B" =>  "6d",  "01A" =>  "6m",
                    "02B" =>  "7d",  "02A" =>  "7m",
                    "03B" =>  "8d",  "03A" =>  "8m",
                    "04B" =>  "9d",  "04A" =>  "9m",
                    "05B" => "10d",  "05A" => "10m",
                    "06B" => "11d",  "06A" => "11m",
                    "07B" => "12d",  "07A" => "12m" }

  return false
end

def copyPublishedYearToYear(v1Tag, v2Tag)
  return false
end

def cleanKeyCodesFromComments(tag)
  # substrings to strip
  codes = [ 
            # Camelot with and without 0 padding
            "01A",  "1A", "01B", "1B",
            "02A",  "2A", "02B", "2B",
            "03A",  "3A", "03B", "3B",
            "04A",  "4A", "04B", "4B",
            "05A",  "5A", "05B", "5B",
            "06A",  "6A", "06B", "6B",
            "07A",  "7A", "07B", "7B",
            "08A",  "8A", "08B", "8B",
            "09A",  "9A", "09B", "9B",
            "10A", "10B",
            "11A", "11B",
            "12A", "12B",
            # Open Key 
            "1m",   "1d",  "2m",  "2d",
            "3m",   "3d",  "4m",  "4d",
            "5m",   "5d",  "6m",  "6d",
            "7m",   "7d",  "8m",  "9d",
            "9m",   "9d",  "10m","10d",
            "11m", "11d", "12m", "12d",
            # Seperators
            "-", "/"]

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

    id3v1Updated = false
    if $options[:clean_comments] &&
      commentsUpdated = cleanKeyCodesFromComments(tag)
      if commentsUpdated === true and file.id3v1_tag != nil
        #if we updated v2 comments and there is a v1 tag
        #copy the new comments otherwise some software (iTunes)
        #will still read the old v1 comments
        unless $options[:strip_v1]
          id3v1Updated = copyCommentsV2toV1(tag, file.id3v1_tag)          
        end
      end
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

    if $options[:clean_comments]
      if commentsUpdated.is_a? String
        unless $options[:quiet]
          puts "\t" + commentsUpdated
        end
      else
        puts "\t" + (commentsUpdated ? "Comments cleaned" : "Comments didn't contain codes")
      end
    end
    
    if needToSave
      unless $options[:strip_v1]
        #save v2 or v2 & v1. Don't strip anything
        file.save(TagLib::MPEG::File::ID3v2 | (id3v1Updated ? TagLib::MPEG::File::ID3v1 : 0), false) #false prevents id3v1 stripping         
      else
        # Save v2 and strip v1
        file.save(TagLib::MPEG::File::ID3v2, true)
        unless $options[:quiet]
          puts "\tStripping id3v1"
        end
      end
      unless $options[:quiet]
        puts "\tSaved."       
      end
      return 1
    end
  end  # File is automatically closed at block end
  return 0
end

def print2(message)
  unless $options[:quiet]
    puts message
  end
end

def main

# TODO support list of ARGV files and folders
#  ARGV.each do|f|
#   # process directory or file 
#   sleep 0.5
#  end

  searchDirectory = nil
  unless $options[:search_directory] === nil
    searchDirectory = $options[:search_directory]
  else
    searchDirectory = ARGV.last
  end
  mp3FilePaths = []

  if searchDirectory === nil
    puts "No path specified\n"
    puts opts
    exit 1 
  end
  
  if $options[:search_recursive]
    print2 "Searching recursively for mp3's ..."
    mp3FilePaths = Dir.glob("#{searchDirectory}/**/*.mp3")
  else
    print2 "Searching for mp3's ..."
    mp3FilePaths = Dir.glob("#{searchDirectory}/*.mp3")
  end
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
