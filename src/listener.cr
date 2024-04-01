require "http/server"
require "redis"
require "validator"
require "sanitize"
require "json"
require "json_on_steroids"
require "./tools/*"

module Crog
  struct UriEntity
    include JSON::Serializable
    property uri : String
    property timeout : Int32?
  end

  struct Result
    property code : Int32 = 200
    property type : String = "text/plain"
    property text : String = ""
    property json : JSON::OnSteroids = JSON::OnSteroids.new({"title": "", "image": "", "description": "", "site_name": ""})
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
      Log.info { "sanitized_uri: #{uri}" }

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

      mixin = JSON::OnSteroids.new(JSON.parse(@@options.settings.mixin))
      begin
        og = JSON::OnSteroids.new(OpenGraph.from_url(uri))
      rescue Socket::Addrinfo::Error
        Log.error { "Error resolving #{uri}" }
        # write bad one to cache for 10 minutes
        # mixin with default response
        res.json = build_answer(res, mixin)
        Cache.set(uri, res.json.to_json, 360)
        return res
      end

      res.type = "application/json"
      if og["title"]?
        res.json.merge!(og)
        res.json = build_answer(res, mixin)
      end
      # write to cache good or missing
      Cache.set(uri, res.json.to_json)
      res
    end

    private def sanitize_uri(uri : String)
      sanitizer = Sanitize::URISanitizer.new
      sanitizer.sanitize(URI.parse(uri)).to_s
    end

    private def build_answer(data, mixin : JSON::OnSteroids)
      template = @@options.settings.template
      template
      # mixin = JSON::OnSteroids.new(JSON.parse(@@options.settings.mixin))
      payload = JSON::OnSteroids.new(data.json)
      # adding mixin
      payload.merge!(mixin)
      # place it in the template
      JSON::OnSteroids.new(JSON.parse(template.gsub("<data>", payload)))
    end
  end
end
