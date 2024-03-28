require "http/server"
require "json"
require "redis"
require "validator"
require "sanitize"
require "./tools/*"

module Crog
  class UriEntity
    include JSON::Serializable
    property uri : String
    property timeout : Int32?
  end

  class Result
    property code : Int32 = 200
    property type : String = "text/plain"
    property text : String = ""
    property json : Hash(String, String) = {"title" => "", "image" => "", "description" => "", "site_name" => "", "contentType" => "OpenGraph"}
  end

  class Listener
    @@options = Options.new
    Log   = ::Log.for("listener")
    Log.level = :debug
    Cache = RedisCache.new(@@options.settings.redis_host, @@options.settings.redis_port)

    def initialize
      server = HTTP::Server.new([
        HTTP::ErrorHandler.new,
        HTTP::LogHandler.new,
        HTTP::CompressHandler.new,
      ]) do |context|
        result = parse_and_answer(context.request)
        context.response.content_type = result.type
        context.response.status_code = result.code
        output = result.text.empty? ? result.json.to_json : result.text
        context.response.print output
      end
      server.bind_tcp @@options.settings.host, @@options.settings.port
      Log.info { "Listening on #{@@options.settings.host}:#{@@options.settings.port}" }

      server.listen
    end

    private def parse_and_answer(request : HTTP::Request)
      res = Result.new
      if request.method == "POST" && request.body != nil
        body = request.body.not_nil!.gets_to_end
        begin
          JSON.parse(body)
        rescue JSON::ParseException
          res.code, res.text = 500, "Invalid JSON"
          Log.error { "Invalid JSON #{body}" }
          return res
        end
        uri = UriEntity.from_json(body)
        res = parse_uri(uri)
      elsif request.method == "GET"
        res.code, res.text = 200, "Healthy"
      else
        res.code, res.text = 422, "Unprocessable request"
      end
      res
    end

    private def parse_uri(uri_entity : UriEntity)
      res = Result.new
      uri = sanitize_uri(uri_entity.uri)
      Log.info { "san: #{uri}" }

      unless Valid.domain?(uri) || Valid.url?(uri)
        res.code, res.text = 500, "Invalid uri provided"
        return res
      end
      # check if it is already cached
      cached = Cache.get(uri)

      if cached
        Log.debug { "Using cache!" }
        res.text = cached.to_s
        return res
      end

      begin
        og = OpenGraph.from_url(uri)
      rescue Socket::Addrinfo::Error
        # res.code, res.text = 404, "Error resolving #{uri}"
        Log.error { "Error resolving #{uri}" }
        # write bad one to cache for 10 minutes
        Cache.set(uri, res.json.to_json, 360)
        return res
      end

      res.type = "application/json"
      res.json.merge!(og) if og["title"]?
      # write to cache good or missing
      Cache.set(uri, res.json.to_json)
      res
    end

    private def sanitize_uri(uri : String)
      sanitizer = Sanitize::URISanitizer.new
      sanitizer.sanitize(URI.parse(uri)).to_s
    end
  end
end
