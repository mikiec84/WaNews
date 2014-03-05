

require 'rubygems'
#require 'sinatra'
require 'json'
require 'httparty'
require 'chronic'
require 'time'
require 'tempfile'
require 'uri'
require 'deep_merge/rails_compat'

#require 'fileutils'


# get recent news feed (from test file or from live server)
# merge results into a single structure
# loop through results
#   increment a counter for each unique doc id
# find all unique doc ids > min_num_edits
# convert doc ids to URLs
# return URLs


module WaNews
  module GetNews
    # number of edits to be included in news feed
    DEFAULT_MIN_NUM_EDITS = 5
    # time range to analyze to determine news worthy stories
    DEFAULT_NEWS_FEED_TIME_RANGE_HOURS = "24 hours" 
    DEFAULT_CACHED_FILE = Tempfile.new('WaNewsAPICacheFile')
    def self.getRecentEdits(options = {})
      min_num_edits = options[:min_num_edits] || DEFAULT_MIN_NUM_EDITS
      time_range = options[:time_range] || DEFAULT_NEWS_FEED_TIME_RANGE_HOURS
      # must be an IO writable object - like a tempfile
      cached_results = options[:cached_results] || DEFAULT_CACHED_FILE
      # if there are no contents in the cached file, the pull from the api
      if cached_results.size == 0
        puts "Pulling data from Wikipedia API"
        start_time = Chronic.parse("#{time_range} before now").gmtime.iso8601
        rccontinue = nil
        tempfiles = []

        # get all the recent changes from wikipedia within our time window
        while start_time
          if rccontinue
            puts "continuing: #{Time::iso8601(URI::decode(rccontinue).match(/([^|]+)|/)[1])}"
            api_url = "http://en.wikipedia.org/w/api.php?action=query&list=recentchanges&format=json&rccontinue=#{rccontinue}&rcnamespace=0&rcshow=!minor%7C!bot%7C!anon%7C!redirect&rclimit=500&rcdir=newer"
          else
            puts "starting: #{Time::iso8601(start_time)}"
            api_url = "http://en.wikipedia.org/w/api.php?action=query&list=recentchanges&format=json&rcstart=#{start_time}&rcnamespace=0&rcshow=!minor%7C!bot%7C!anon%7C!redirect&rclimit=500&rcdir=newer"
          end
          response = HTTParty.get(api_url, {:headers => {"User-Agent" => 'WaNews/0.1 public@misuse.org'}})
          tempfiles.push(Tempfile.new('WaNewsAPICacheIntermediateFile'))
          results_file = tempfiles.last
          results_file.write(response.body)
          results_file.rewind
          json = JSON.parse(results_file.read)
          if json["query-continue"] && json["query-continue"]["recentchanges"] && json["query-continue"]["recentchanges"]["rccontinue"]
            rccontinue = json["query-continue"]["recentchanges"]["rccontinue"]
            puts rccontinue
            break if !rccontinue
            if rccontinue
              puts "***"
              puts Time::iso8601(rccontinue.match(/([^|]+)|/)[1])
              puts start_time
              puts Time::iso8601(rccontinue.match(/([^|]+)|/)[1]) < Time::iso8601(start_time)
              break if Time::iso8601(rccontinue.match(/([^|]+)|/)[1]) < Time::iso8601(start_time)
            end
            rccontinue = URI::encode_www_form_component(rccontinue)
          else
            start_time = nil
          end
        end
        
        recentchanges = {}
        # we merge all the json together and write it out to a file
        tempfiles.each do |f|
          f.rewind
          json = JSON.parse(f.read)
          query = json["query"]
          recentchanges.deeper_merge!(query)
        end
        # write the merged data back to cache file as json
        cached_results.write(JSON.generate(recentchanges))
      end # if cached_results.size...
    end # self.getRecentEdits
  end # GetNews
end # WaNews

file = File::open('results_wanews.json', 'a+')
WaNews::GetNews::getRecentEdits(:cached_results => file, :time_range => "60 minutes")

file.rewind
recent  = JSON.parse(file.read)
puts recent["recentchanges"].size


# set :server, 'thin'
# set :port, 80

# ## Application server (generates user interface from erb templates)

# get "/news" do
#   WaNews::GetNews::getRecentEdits
# end
