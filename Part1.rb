require "json"
require "open-uri"

NUM_NEXT_BUSES = 5
WIDTH_OF_LINE_SECTION = 10
WIDTH_OF_DESTINATION_SECTION = 30
WIDTH_OF_ARRIVING_SECTION = 12

class LiveBusStop
    def initialize(data)
        @data = data
    end
    
    def name()
        return @data.first['stationName']
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

def get_stop_code_from_user_input()
    puts
    puts 'Welcome to BusBoard.'
    puts
    puts 'Please input a stop code: '
    return gets.chomp
end

def get_application_key()
    data = File.read('secrets.txt').split

    # Either substitute your API key here or write a secrets.txt file with the key in the first line
    return data[0]
end

def get_stop_data_from_api(stop_code)
    app_key = get_application_key()
    request_url = "https://api.tfl.gov.uk/StopPoint/#{stop_code}/Arrivals?app_key=#{app_key}"

    api_response_serialised = URI.open(request_url).read
    api_response_json = JSON.parse(api_response_serialised)

    return LiveBusStop.new(api_response_json)
end

def display_busboard(stop)
    puts
    puts 'These are the upcoming buses at ' + stop.name() + ':'
    puts
    puts 'Line'.ljust(WIDTH_OF_LINE_SECTION) + 'Destination'.ljust(WIDTH_OF_DESTINATION_SECTION) + 'Arriving in'
    puts '-' * (WIDTH_OF_LINE_SECTION + WIDTH_OF_DESTINATION_SECTION + WIDTH_OF_ARRIVING_SECTION)
    puts stop.next_arrivals_summary(NUM_NEXT_BUSES)
    puts
end

def run_app()
    stop_code = get_stop_code_from_user_input()

    begin
        stop = get_stop_data_from_api(stop_code)
    rescue
        puts
        puts "Sorry, that is an invalid stop code."
        puts
    else
        display_busboard(stop)
    end
end

run_app()