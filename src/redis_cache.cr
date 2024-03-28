# redis cache module

require "redis"

module Crog
  class RedisCache
    Log = ::Log.for("cache")

    def initialize(host : String, port : Int32)
      # begin
      @redis = Redis::PooledClient.new(host, port, reconnect: true)
      # rescue Redis::CannotConnectError
      #   Log.error { "Redis connection failed" }
      #   return
      # end
      Log.info { "Cache ignited on redis #{host}:#{port}" } if @redis.ping
    end

    def get(key : String)
      @redis.get(key) || false
    end

    def set(key : String, value : String, ttl : Int32 = 3600)
      @redis.set(key, value, ex: ttl)
    end
  end
end
