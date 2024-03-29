require 'sinatra/base'
require "sinatra/reloader"
require 'sinatra/json'
require 'json'
require 'mysql2-cs-bind'
require 'digest/sha2'
require 'tempfile'
require 'fileutils'
require 'uuid'
require 'zip'
require 'debugger'
require File.expand_path '../helpers.rb', __FILE__

class NetPrint < Sinatra::Base
  $UUID    = UUID.new

  helpers Util

  configure do
    enable :sessions
  end
  configure :development do
    set :bind, '0.0.0.0'
    register Sinatra::Reloader
  end

  get '/' do
    redirect to('/login')
#    erb :index
  end

  get '/login' do
    erb :login
  end

  post '/doLogin' do
    mysql = connection

    input_login_id = params[:login_id]
    input_password = params[:password]

    unless input_login_id
      halt 400, "ログインIDは必須です"
    end
    unless input_password
      halt 400, "パスワードは必須です"
    end

    hasshed_password = get_hasshed_password(input_password)
    account = mysql.xquery("SELECT * FROM account WHERE login_id = ? AND password = ?", input_login_id, hasshed_password).first
    if account
      session.clear
      session["account_id"] = account["account_id"]
      session["token"] = Digest::SHA256.hexdigest(Random.new.rand.to_s)
      if account["role"] == 1
        redirect("/user")
      elsif account["role"] == 9
        redirect("/admin/albumList")
      end
    else
      halt 400, "ログイン失敗"
    end
  end

  # Move to this page after login. User can upload photos here.
  get '/user' do
    mysql = connection
    erb :user
  end

  # Upload photo
  post '/user/upload' do
    mysql = connection
    check_token

    files = params[:files]
    unless files
      halt 400, "400 Bad Request"
    end

    dir = '/share/app/data' # load_config['data_dir']

    result = '{"files": ['

    $i = 0
    files.each do |file|
      if $i > 0
        result += ','
      end
      $i +=1
      unless file[:type].match(/^image\/(jpe?g|png)$/)
        halt 400, "400 Bad Request"
      end
      photo_hash = Digest::SHA256.hexdigest($UUID.generate)
      FileUtils.move(file[:tempfile].path, "#{dir}/photo/#{photo_hash}.#{file[:type].match(/^image\/(jpe?g|png)$/)[1]}") or halt 500

      mysql.xquery(
        'INSERT INTO photo (photo_hash, account_id, file_name, extension) VALUES (?, ?, ?, ?)',
        photo_hash, session["account_id"], file[:filename], file[:type].match(/^image\/(jpe?g|png)$/)[1]
      )
      id    = mysql.last_id
      photo = mysql.xquery('SELECT * FROM photo WHERE photo_id = ?', id).first

      result += <<EOS
      {
        "id": "#{photo["photo_id"]}",
        "name": "#{photo["file_name"]}",
        "url": "\/data\/photo\/#{photo["photo_id"]}",
        "thumbnailUrl": "\/data\/photo\/#{photo["photo_id"]}",
        "deleteUrl": "\/delete\/#{photo["photo_id"]}",
        "deleteType": "DELETE"
      }
EOS
    end

    result += ']}'
    json(JSON.parse(result))
  end

  post '/user/submit' do
    mysql = connection
    check_token

    quantity = params["quantity"]
    unless quantity
      halt 400, "no photo selected"
    end

    mysql.xquery(
      'INSERT INTO album (account_id, delivery_address, status) VALUES (?, ?, 1)',
      session["account_id"], ""
    )
    album_id = mysql.last_id

    quantity.each do |photo|
      quantity
      mysql.xquery(
        'INSERT INTO photo_album_relation (album_id, photo_id, quantity) VALUES (?, ?, ?)',
        album_id, photo.split("_")[0], photo.split("_")[1]
      )
    end

    # Create ZIP file
    photos = mysql.xquery(
      'SELECT * FROM photo p INNER JOIN photo_album_relation par ON p.photo_id = par.photo_id AND par.album_id = ?',
      album_id
    )

    dir = '/share/app/data' # load_config['data_dir']
    zipfile_name = "#{dir}/zip/album_#{album_id}.zip"
    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      photos.each do |photo|
        "#{dir}/photo/#{photo['photo_hash']}.#{photo['extension']}"
      end
    end
    "success"
  end

  # Show photo
  get '/data/photo/:photo_id' do
    mysql = connection
    check_token

    photo_id = params[:photo_id]
    photo = mysql.xquery('SELECT * FROM photo WHERE photo_id = ?', photo_id).first

    dir  = './data' # load_config['data_dir']
    dir  = '/share/app/data' # load_config['data_dir']

    file_path = "#{dir}/photo/#{photo["photo_hash"]}.#{photo["extension"]}"
    unless File.exist?(file_path)
      halt 404
    end

    file = File.open(file_path)
    data = file.read
    file.close

    content_type "image/#{photo["extension"]}"
    data
  end

  # Move to this page after login for admin. Show album list.
  get '/admin/albumList' do
    mysql = connection

    @album_list = mysql.xquery(
      'SELECT * FROM album INNER JOIN account ON album.account_id = account.account_id ORDER BY album.created_at DESC'
    )

    erb :album_list
  end

  # Show album detail.
  get '/admin/album/:album_id' do
    mysql = connection

    album_id = params['album_id']
    @photo_list = mysql.xquery(
        'SELECT * FROM photo INNER JOIN photo_album_relation ON photo.photo_id = photo_album_relation.photo_id AND photo_album_relation.album_id = ?',
        album_id
    )

    erb :photo_list
  end

  run! if app_file == $0
end
