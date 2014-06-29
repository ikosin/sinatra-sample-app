require 'sinatra/base'
require "sinatra/reloader"
require 'sinatra/json'
require 'json'
require 'mysql2-cs-bind'
require 'digest/sha2'
require 'tempfile'
require 'fileutils'
require 'uuid'

class NetPrint < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    redirect to('/login')
#    erb :index
  end

  get '/login' do
    erb :login
  end

  def hash(str)
    solt = "Euzd{?.B4huzKTk7m494r#L+Zc4M3(sptg#zieMh46V$n=o8{v"
    Digest::SHA256.hexdigest(str + solt)
  end

  def get_hasshed_password(password)
    $i = 0
    $num = 5

    while $i < $num  do
      password = hash(password)
      $i +=1
    end
    password
  end

  post '/doLogin' do
    input_password = params[:password]
    hasshed_password = get_hasshed_password(input_password)
  end

  # Move to this page after login. User can upload photos here.
  get '/user' do
    erb :user
  end

  post '/user/upload' do
  end

  post '/user/submit' do
  end

  # Move to this page after login for admin. Show album list.
  get '/admin/albumList' do
    erb :admin
  end

  # Show album detail.
  get '/admin/album/:album_id' do
    erb :photo_list
  end

  run! if app_file == $0
end
