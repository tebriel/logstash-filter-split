require "logstash/filters/base"
require "logstash/namespace"
require "logstash/event"

# JSON filter. Takes a field that contains JSON and expands it into
# an actual datastructure.
class LogStash::Filters::Json < LogStash::Filters::Base

  config_name "json"
  milestone 2

  # Config for json is:
  #
  #     source => source_field
  #
  # For example, if you have json data in the @message field:
  #
  #     filter {
  #       json {
  #         source => "message"
  #       }
  #     }
  #
  # The above would parse the json from the @message field
  config :source, :validate => :string, :required => true

  # Define target for placing the data. If this setting is omitted,
  # the json data will be stored at the root of the event.
  #
  # For example if you want the data to be put in the 'doc' field:
  #
  #     filter {
  #       json {
  #         target => "doc"
  #       }
  #     }
  #
  # json in the value of the source field will be expanded into a
  # datastructure in the "target" field.
  #
  # Note: if the "target" field already exists, it will be overwritten.
  config :target, :validate => :string

  # Define a key containing an array of events to be split up and fed into LogStash as separate individual events.
  config :array_split, :validate => :string

  public
  def register
    # Nothing to do here
  end # def register

  public
  def filter(event)
    return unless filter?(event)

    @logger.debug("Running json filter", :event => event)

    return unless event.include?(@source)

    if @target.nil?
      # Default is to write to the root of the event.
      dest = event.to_hash
    else
      dest = event[@target] ||= {}
    end

    begin
      source = JSON.parse(event[@source])

      if !!@array_split

        source[@array_split].each do |item|
          next if item.empty?

          event_split = LogStash::Event.new(item.clone)
          @logger.debug("JSON Array Split item", :value => event_split)
          filter_matched(event_split)

          yield event_split # yield each item to be handled individually
        end
        event.cancel

      else
        dest.merge!(JSON.parse(event[@source]))

        # This is a hack to help folks who are mucking with @timestamp during
        # their json filter. You aren't supposed to do anything with "@timestamp"
        # outside of the date filter, but nobody listens... ;)
        if event["@timestamp"].is_a?(String)
          event["@timestamp"] = Time.parse(event["@timestamp"]).gmtime
        end

        filter_matched(event)
      end

    rescue => e
      event.tag("_jsonparsefailure")
      @logger.warn("Trouble parsing json", :source => @source,
                   :raw => event[@source], :exception => e)
      return
    end

    @logger.debug("Event after json filter", :event => event)

  end # def filter

end # class LogStash::Filters::Json