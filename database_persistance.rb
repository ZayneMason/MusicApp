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
    sql = "INSERT INTO users(username, pass) VALUES ($1, crypt($2, gen_salt('bf')))"
    query(sql, username, password)
    sql = "INSERT INTO follows(username, follower) VALUES ($1, $2)"
    query(sql, username, username)
  end

  def get_posts_for_list(username)
    sql = <<~SQL
    SELECT posts.id, posts.username, posts.time_of, posts.caption, 
    posts.song_link, count(likes.username) AS post_likes FROM posts
    INNER JOIN follows ON posts.username = follows.username
    LEFT OUTER JOIN likes ON likes.post_id = posts.id
    WHERE follows.follower = $1
    GROUP BY posts.id
    ORDER BY posts.time_of DESC
    SQL
    result = @db.exec_params(sql, [username])

    result.map do |tuple|
      {
        id: tuple["id"],
        username: tuple["username"],
        time_of_post: tuple["time_of"],
        caption: tuple["caption"],
        song_link: tuple["song_link"],
        likes: tuple["post_likes"]
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

  def get_post_thread(post_id)
    post = {
      id: '',
      username: '',
      time_of_post: '',
      caption: '',
      song_link: '',
      likes: '',
      comments: []
      }

    sql = <<~SQL
    SELECT posts.id, posts.username, posts.time_of, posts.caption, 
    posts.song_link, count(likes.username) AS post_likes FROM posts
    LEFT OUTER JOIN likes ON likes.post_id = posts.id
    WHERE posts.id = $1
    GROUP BY posts.id
    ORDER BY posts.time_of DESC
    SQL
    result = @db.exec_params(sql, [post_id])


    result.each do |tuple|
        post[:id] = tuple["id"]
        post[:username] = tuple["username"]
        post[:time_of_post] = tuple["time_of"]
        post[:caption] = tuple["caption"]
        post[:song_link] = tuple["song_link"]
        post[:likes] = tuple["post_likes"]
    end
    sql = "SELECT username, comment, time_of FROM comments WHERE post_id = $1"
    next_result = @db.exec_params(sql, [post_id])
    next_result.each do |tuple|
      post[:comments] << { comment_username: tuple["username"],
                           comment_comment: tuple["comment"],
                           comment_time: tuple["time_of"] }
    end
    post
  end

  def create_comment(username, post_id, comment)
    sql = "INSERT INTO comments(username, post_id, comment) VALUES ($1, $2, $3)"
    @db.exec_params(sql, [username, post_id, comment])
  end
  
  private

  # Abstracts out manually creating debug lines each time we run an sql query.
  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end
end
