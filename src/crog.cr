# opengraph daemon
require "log"
require "./tools/*"
require "./listener"
require "./redis_cache"
# require "crometheus"
require "opengraph"

module Crog
  VERSION = "0.0.1"
  Log     = ::Log.for("main")

  class Daemon
    # options = Options.new
    Log.info { "crog version #{VERSION} started" }
    # Log.level = :debug if options.settings.debug?

    Listener.new
  end
end
