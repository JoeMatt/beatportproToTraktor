#!/usr/bin/env ruby
#
#
#
#
# <plist>
# <dict>
# <key>Playlists</key
# <array>
# 	<dict>
# 		<key>Name</key><string>Library</string>
# 		<key>Playlist ID</key><integer>5829</integer>
# 		<key>Playlist Persistent ID</key><string>0AAD65ED84A6BAF1</string>
# 		<key>Music</key><true/>
# 		<key>All Items</key><true/>
# 		<key>Folder</key><true/>      <!-- Folder -->
# 		<key>Playlist Items</key>
# 		<array>
# 			<dict>
# 				<key>Track ID</key><integer>2403</integer>
# 			</dict>
# 		</array>
# 	</dict>
# </arary>
require 'optparse'

inputfile = ARGV[0]

parser = Nokogiri::XML::SAX::Parser.new( ITunesLibraryCallbacks.new( f ) )
parser.parse_file( inputfile )

#collection of callbacks for SAX parser
class ITunesLibraryCallbacks < Nokogiri::XML::SAX::Document
  def initialize(filehandle)
    @filehandle = filehandle
  end
  def characters str
    @filehandle << str
  end
  def start_element element_name, attributes
    case element_name
    when "plist"
      @filehandle << '<plist version="1.0">'
    else
      @filehandle << "<#{element_name}>"
    end
  end
  def end_element element_name
    @filehandle << "</#{element_name}>"
  end
  def error error_message
    abort "ERROR: #{error_message}"
  end
end