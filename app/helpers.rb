  module Util
    def connection
      config = JSON.parse(<<EOS
        {
          "host": "localhost",
          "port": 3306,
          "username": "root",
          "password": "",
          "dbname": "netprint"
        }
EOS
      )
      return $mysql if $mysql
      $mysql = Mysql2::Client.new(
        :host => config['host'],
        :port => config['port'],
        :username => config['username'],
        :password => config['password'],
        :database => config['dbname'],
        :reconnect => true,
      )
    end

    def check_token
      if params["token"] != session["token"]
#        halt 400, "400 Bad Request. Token invalid"
      end
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
  end
