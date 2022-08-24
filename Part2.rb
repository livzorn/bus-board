require "json"
require "open-uri"

NUM_NEXT_BUSES = 5
WIDTH_OF_LINE_SECTION = 10
WIDTH_OF_DESTINATION_SECTION = 30
WIDTH_OF_ARRIVING_SECTION = 12

def get_application_key()
    data = File.read('secrets.txt').split

    # Either substitute your API key here or write a secrets.txt file with the key in the first line
    return data[0]
end

def get_json_response_from_api(request_url)
    api_response = URI.open(request_url).read
    return JSON.parse(api_response)
end

class TransportAPI
    def initialize()
        @app_key = get_application_key()
    end

    def get_two_stop_codes_nearest(latitude, longitude)
        request_url = "https://api.tfl.gov.uk/StopPoint?stopTypes=NaptanPublicBusCoachTram&lat=#{latitude}&lon=#{longitude}&radius=1000&app_key=#{@app_key}"
        data = get_json_response_from_api(request_url)

        nearest_two_stop_codes = []
        data['stopPoints'].first(2).each { |stop| nearest_two_stop_codes.push(stop['naptanId']) }
        return nearest_two_stop_codes
    end

    def get_live_bus_stop(stop_code)
        request_url = "https://api.tfl.gov.uk/StopPoint/#{stop_code}/Arrivals?app_key=#{@app_key}"
        data = get_json_response_from_api(request_url)

        return LiveBusStop.new(data)
    end
end

class LiveBusStop
    def initialize(data)
        @data = data
    end
    
    def name()
        return @data.first['stationName']
    end
    
    def direction()
        return @data.first['direction']
    end

    def next_arrivals_summary(num_next_buses)
        arrival_summaries = []

        next_arrivals = @data.sort_by { |object| object['timeToStation'] }        
            .first(num_next_buses).each { |bus_data| 
                arriving_bus = Bus.new(bus_data)
                arrival_summaries.push(arriving_bus.arrival_summary)
            }
    
        return arrival_summaries.join("\n")
    end
end

class Bus
    def initialize(data)
        @data = data
    end
    
    def line_name()
        return @data['lineName']
    end

    def time_until_arrival()
        time_in_minutes = @data['timeToStation'] * 0.01
        return time_in_minutes.round
    end

    def destination_name()
        return @data['destinationName']
    end

    def arrival_summary()
        return line_name().ljust(WIDTH_OF_LINE_SECTION) + 
                destination_name.ljust(WIDTH_OF_DESTINATION_SECTION) + 
                time_until_arrival.to_s + ' min'
    end
end

class PostcodeAPI
    def get_postcode_details(postcode)
        postcode_data = get_json_response_from_api("https://api.postcodes.io/postcodes/#{postcode}")

        if postcode_data['status'] != 200
            return nil
        end

        postcode = Postcode.new(postcode_data)
        return postcode
    end
end

class Postcode
    def initialize(data)
        @data = data['result']
    end
    
    def longitude()
        return @data['longitude']
    end

    def latitude()
        return @data['latitude']
    end
end

def get_postcode_from_user_input()
    puts
    puts 'Welcome to BusBoard.'
    puts
    puts 'Please input a postcode: '
    return gets.chomp
end

def display_busboard(stop)
    puts
    puts "These are the upcoming #{stop.direction()} buses at " + stop.name() + ':'
    puts
    puts 'Line'.ljust(WIDTH_OF_LINE_SECTION) + 'Destination'.ljust(WIDTH_OF_DESTINATION_SECTION) + 'Arriving in'
    puts '-' * (WIDTH_OF_LINE_SECTION + WIDTH_OF_DESTINATION_SECTION + WIDTH_OF_ARRIVING_SECTION)
    puts stop.next_arrivals_summary(NUM_NEXT_BUSES)
    puts
end

def run_app()
    postcodeApi = PostcodeAPI.new
    transportApi = TransportAPI.new

    postcode_string = get_postcode_from_user_input()
    postcode_data = postcodeApi.get_postcode_details(postcode_string)

    if postcode_data == nil
        puts
        puts "Sorry, that is an invalid postcode."
        puts
        return
    end

    stopcodes = transportApi.get_two_stop_codes_nearest(postcode_data.latitude(), postcode_data.longitude())

    stopcodes.each do |stopcode| 
        stop = transportApi.get_live_bus_stop(stopcode) 
        display_busboard(stop)
    end
end

run_app()