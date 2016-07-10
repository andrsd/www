#!/usr/bin/ruby -w
#
# Stupid and dump GPX file analyzer
#
# Computes:
# - distance
# - duration
# - climb
#

require 'time'
require 'yaml'
require 'rexml/document'
include REXML

class Float
  def to_rad
    self / 180.0 * Math::PI
  end
end

class Run
  # radius of Earth in meter
  R = 6371000.0

  def initialize(gpx_name)
    @gpx_name = gpx_name

    @title = ""
    @gpx = "/" + gpx_name
    @duration = 0
    @distance = 1
    @total_climb = 0
    @elevation = Array[ ]
    @max_ele = -10000       # solid pressure this deep
    @min_ele =  10000       # higher than mount everest
    @max_pace = -1
    @min_pace =  10000
    @map_center_lat = 0
    @map_center_lon = 0
    @start_lat = 0
    @start_lon = 0
  end

  def meters_to_miles(meters)
    return meters / 1609.34
  end

  def meters_to_kms(meters)
    return meters / 1000.0
  end

  def meters_to_feet(meters)
    return meters * 3.28084
  end

  def pace_fmt(pace)
    mins = (pace / 60.0).to_i
    secs = (pace.to_i % 60)
    return sprintf("%d:%02d", mins, secs)
  end

  # haversine distnace between to points in meters
  def distance(lat1, lon1, lat2, lon2)
    phi1 = lat1.to_rad
    phi2 = lat2.to_rad
    dphi = (lat2 - lat1).to_rad
    dlambda = (lon2 - lon1).to_rad
    a = Math.sin(dphi / 2) * Math.sin(dphi / 2) + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlambda / 2) * Math.sin(dlambda / 2)
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    return Run::R * c
  end

  def analyze
    n = 0
    start_time = Time.new(0)

    gpx_file = File.new(@gpx_name)
    gpx = Document.new(gpx_file)

    first = true
    last_time = 0
    last_lat = 0
    last_lon = 0
    last_ele = 0
    split_climb = 0
    split_time = 0
    km = 0
    time = nil

    gpx.elements.each("gpx/trk/trkseg/trkpt") {
      |e|
      lat = e.attributes["lat"].to_f
      lon = e.attributes["lon"].to_f
      ele = e.elements["ele"].text.to_f
      time = Time.parse(e.elements["time"].text).to_time

      if ele > @max_ele
        @max_ele = ele
      end
      if ele < @min_ele
        @min_ele = ele
      end

      if (first)
        last_time = time
        start_time = time
        split_climb = 0
        split_time = start_time
        @start_lon = lon
        @start_lat = lat
        first = false
      else
        if ele > last_ele
          @total_climb += ele - last_ele
        end
        distance_inc = distance(last_lat, last_lon, lat, lon)
        @distance = @distance + distance_inc
        @duration = time - start_time
        if distance_inc > 0 and time - last_time > 0
          p = ((time - last_time) / meters_to_kms(distance_inc)).round(0).to_i
          if p > @max_pace
            @max_pace = p
          end
          if p < @min_pace
            @min_pace = p
          end
        end

        km = meters_to_kms(@distance).ceil
      end
      last_time = time
      last_lat = lat
      last_lon = lon
      last_ele = ele
      @elevation.push(ele)
      @map_center_lat = @map_center_lat + lat
      @map_center_lon = @map_center_lon + lon
      n = n + 1
    }
    #
    case start_time.wday
    when 0
      @title = "Sunday"
    when 1
      @title = "Monday"
    when 2
      @title = "Tuesday"
    when 3
      @title = "Wednesday"
    when 4
      @title = "Thursday"
    when 5
      @title = "Friday"
    when 6
      @title = "Saturday"
    end
    @title = @title + " run"
    # compute the map center
    @map_center_lat /= n
    @map_center_lon /= n
  end

  def output
    puts "---"
    puts "layout: hike"
    puts "gpx: " + "'" + @gpx + "'"
    puts "map:"
    puts "  center: '" + @map_center_lon.to_s + ", " + @map_center_lat.to_s + "'"
    puts "  zoom: 12"
    puts "distance: " + meters_to_kms(@distance).round(2).to_s
    puts "duration: '" + Time.at(@duration).utc.strftime("%H:%M:%S") + "'";
    puts "total_climb: " + @total_climb.round(0).to_s
    # puts "elevation:"
    # for i in @elevation
    #   puts "  - " + i.to_s
    # end
    puts "min_ele: " + @min_ele.to_s
    puts "max_ele: " + @max_ele.to_s
    puts "start: '" + @start_lon.to_s + ", " + @start_lat.to_s + "'"
    puts "---"
  end
end

main = Run.new(ARGV[0])
main.analyze
main.output
