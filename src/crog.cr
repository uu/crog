# opengraph daemon
require "log"
require "./tools/*"
require "./listener"
require "./redis_cache"
# require "crometheus"
require "opengraph"

module Crog
  VERSION = "0.0.2"
  Log     = ::Log.for("main")

  class Daemon
    Log.info { "crog version #{VERSION} started" }
    Listener.new
  end
end
