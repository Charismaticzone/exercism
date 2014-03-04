$:.unshift File.expand_path("./../lib", __FILE__)

require 'bundler'
Bundler.require

require 'app'
require 'api'
require 'v1.0'
require 'sass/plugin/rack'

use Sass::Plugin::Rack
Sass::Plugin.options[:template_location] = "./lib/redesign/public/stylesheets/sass"
Sass::Plugin.options[:css_location] = "./lib/redesign/public/css"

ENV['RACK_ENV'] ||= 'development'

key = ENV['NEW_RELIC_LICENSE_KEY']
if key
  NewRelic::Agent.manual_start(license_key: key)
end

if ENV['RACK_ENV'].to_sym == :development
  require 'new_relic/rack/developer_mode'
  use NewRelic::Rack::DeveloperMode
end

use ActiveRecord::ConnectionAdapters::ConnectionManagement
run ExercismApp

map '/api/v1/' do
  run ExercismAPI
end

map '/v1.0/' do
  run ExercismV1p0
end

require 'redesign'
map '/redesign/' do
  run ExercismIO::Redesign
end
