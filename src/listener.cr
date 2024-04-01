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
    property url : String
    property timeout : Int32?
  end

  struct Result
    property code : Int32 = 200
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
        context.response.content_type = "application/json"
        context.response.status_code = result.code
        context.response.print result.json.to_json
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
          uri_ent = UriEntity.from_json(body)
        rescue ex: JSON::ParseException | JSON::SerializableError
          res.code = 500
          Log.error { "POST Invalid JSON #{body}. #{ex.message}" }
          return res
        end
        res = parse_uri(uri_ent)
      elsif request.method == "GET" && request.path =~ /^(\/|\/favicon\.ico)$/
        res.json = build_answer(res)
      elsif request.method == "GET"
        begin
          req = URI.decode(request.query.to_s)
          uri_ent = UriEntity.from_json(req)
        rescue ex: JSON::ParseException | JSON::SerializableError
            Log.error { "GET Invalid JSON #{req.to_s}. #{ex.message}" }
            res.json = build_answer(res)
            return res
        end
        res = parse_uri(uri_ent)
      else
        res.code = 422
      end
      res
    end

    private def parse_uri(uri_entity : UriEntity)
      res = Result.new
      uri = sanitize_uri(uri_entity.url)
      Log.info { "sanitized_uri: #{uri}" }

      unless Valid.domain?(uri) || Valid.url?(uri)
        res.code = 500
        res.json = build_answer(res)
        return res
      end
      # check if it is already cached
      cached = Cache.get(uri)

      if cached
        Log.debug { "Using cache!" }
        res.json = JSON::OnSteroids.new(JSON.parse(cached.to_s))
        return res
      end

      begin
        og = JSON::OnSteroids.new(OpenGraph.from_url(uri))
      rescue Socket::Addrinfo::Error
        Log.error { "Error resolving #{uri}" }
        # write bad one to cache for 10 minutes
        # mixin with default response
        res.json = build_answer(res)
        Cache.set(uri, res.json.to_json, 360)
        return res
      end

      res.json.merge!(og) if og["title"]?
      res.json = build_answer(res)
      # write to cache good or missing
      Cache.set(uri, res.json.to_json)
      res
    end

    private def sanitize_uri(uri : String)
      sanitizer = Sanitize::URISanitizer.new
      sanitizer.sanitize(URI.parse(uri)).to_s
    end

    private def build_answer(data)
      template = @@options.settings.template
      mixin = JSON::OnSteroids.new(JSON.parse(@@options.settings.mixin))
      payload = JSON::OnSteroids.new(data.json)
      # adding mixin
      payload.merge!(mixin)
      # place it in the template
      JSON::OnSteroids.new(JSON.parse(template.gsub("<data>", payload)))
    end
  end
end
