require "pg"

class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASEURL'])
    else
      PG.connect(dbname: "music_app")
    end
    # Logger will be used to output our queries in the terminal for debugging.
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def valid_user?(username, password)
    sql = "SELECT username FROM users WHERE username = $1 AND pass = crypt($2, pass)"
    result = query(sql, username, password)
    !result.values.empty? && username == result.values[0][0]
  end

  def valid_username?(username)
    sql = "SELECT username FROM users WHERE username = $1"
    result = @db.exec_params(sql, [username])
    result.values.empty?
  end

  def create_user(username, password)
    sql = "INSERT INTO users(username, pass) VALUES ($1, crypt($2, gen_salt('bf'))"
    query(sql, username, password)
    sql = "INSERT INTO follows(username, follower) VALUES ($1, $2)"
    query(sql, username, username)
  end

  def get_posts_for_list(username)
    sql = <<~SQL
    SELECT posts.username, posts.time_of, posts.caption, posts.song_link FROM posts
    INNER JOIN follows ON posts.username = follows.username
    WHERE follows.follower = $1
    ORDER BY posts.time_of DESC
    SQL
    result = @db.exec_params(sql, [username])

    result.map do |tuple|
      {
        username: tuple["username"],
        time_of_post: tuple["time_of"],
        caption: tuple["caption"],
        song_link: tuple["song_link"]
      }
    end
  end

  def create_post(song_link, caption, username)
    sql = <<~SQL
    INSERT INTO posts(song_link, caption, username)
    VALUES($1, $2, $3)
    SQL
    @db.exec_params(sql, [song_link, caption, username])
  end
  private

  # Abstracts out manually creating debug lines each time we run an sql query.
  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end
end
