# Opengraph caching proxy

Fetches opengraph meta and translates it to JSON.

## Installation

### Docker

Requirements: `docker-compose 2.24+`

`docker compose up -d`

## Using

`curl localhost:8080 -d '{"uri": "telegram.org"}' && echo`

## Configuring

Mix in JSON object to response.

`--mixin '{"contentType": "openGraph"}'` or `MIXIN` variable in docker-compose

Default: `{}`

Use custom template for response. `<data>` is replaces with default og answer.

`--template '{"meta":{"status":200,"errors":[],"pagination":[]},"data":<data>}'` or `TEMPLATE` variable in docker-compose

Default: `<data>` 

## Contributing

1. Fork it (<https://github.com/uu/crog/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Michael Pirogov](https://github.com/uu) - creator and maintainer
