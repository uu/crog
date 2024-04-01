require "option_parser"

module Crog
  class Settings
    property host = "127.0.0.1"
    property port = 8080
    property redis_host = "127.0.0.1"
    property redis_port = 6379
    property template = "<data>"
    property mixin = "{}"
    property? debug = false
  end

  class Options
    getter settings

    def initialize
      @settings = Settings.new

      OptionParser.parse do |opt|
        opt.banner = "crog [-d] [-h] [-v] [--host 127.0.0.1] [--port 8080] [--redis-host 127.0.0.1] [--redis-port 6379]"

        opt.on("--host 127.0.0.1", "Address listen to") do |host|
          @settings.host = host
        end

        opt.on("--port 8080", "Port listen to") do |port|
          @settings.port = port.to_i
        end

        opt.on("--redis-host 127.0.0.1", "Redis address") do |redis_host|
          @settings.redis_host = redis_host
        end

        opt.on("--redis-port 6379", "Redis port") do |redis_port|
          @settings.redis_port = redis_port.to_i
        end

        opt.on("--template {<data>}", "Template to use") do |template|
          @settings.template = template
        end

        opt.on("--mixin {}", "Mixin to use") do |mixin|
          @settings.mixin = mixin
        end

        opt.on("-d", "If set, debug messages will be shown.") do
          @settings.debug = false
        end

        opt.on("-h", "--help", "Displays this message.") do
          puts opt
          exit
        end

        opt.on("-v", "--version", "Displays version.") do
          puts VERSION
          exit
        end
      end rescue abort "Invalid arguments, see --help."
    end
  end
end
