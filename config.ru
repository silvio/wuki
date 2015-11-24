#!/usr/bin/env ruby

require 'gollum/app'
require 'tilt/erb'
require 'active_record'
require 'sqlite3'
require 'securerandom'

date_config = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.configurations["development"] = date_config["development"]
ActiveRecord::Base.configurations["production"] = date_config["production"]
ActiveRecord::Base.configurations["test"] = date_config["test"]
ActiveRecord::Base.establish_connection ENV["RACK_ENV"].to_sym

require "./model/user.rb"

wiki_config = YAML.load(File.read('gollum_wiki.yml'))
Precious::App.set(:gollum_path, wiki_config["wiki_path"] + '/' + wiki_config["wiki_repo"])
Precious::App.set(:default_markup, wiki_config["default_markup"]) # set your favorite markup language
Precious::App.set(:wiki_options, wiki_config["wiki_options"])
Precious::App.set(:logging, wiki_config["logging"])

class Wuki < Sinatra::Base
  use Rack::Session::Pool, :expire_after => 1 * 24 * 60 * 60,
                           :secret => SecureRandom.hex(64)

  before do
    pass if request.path_info.split('/')[2] == 'auth'
    if !session['user']
      session[:path] = request.path() if session[:path].nil?()
      redirect '/_wuki/auth/login'
    end
  end

  get '/_wuki/auth/login' do
    erb :login
  end

  post '/_wuki/auth/login' do
    if user = User.find_by(email: params['email']) and user.has_password?(params['password'])
      session['user'] = user
      dest = session[:path].length > 1 ? session[:path] : '/'
      session.delete(:path)
      redirect dest
    else
      redirect '/_wuki/auth/login'
    end
  end

  delete '/_wuki/auth/logout' do
    session['user'] = nil
    redirect '/'
  end

  get '/_wuki/auth/logout' do
    session['user'] = nil
    redirect '/'
  end
end

module Myapp
  def self.registered(app)
    app.use Wuki
  end
end

Precious::App.register Myapp
# Precious::App.register Omnigollum::Sinatra
run Precious::App
