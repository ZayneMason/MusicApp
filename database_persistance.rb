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
    result = @db.exec_params(sql, [username, password])
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
    posts.song_link, count(likes.username) AS post_likes,
    count(comments.comment) AS post_comments FROM posts
    INNER JOIN follows ON posts.username = follows.username
    LEFT OUTER JOIN likes ON likes.post_id = posts.id
    LEFT OUTER JOIN comments ON comments.post_id = posts.id
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
        likes: tuple["post_likes"],
        comments: tuple["post_comments"]
      }
    end
  end

  def get_top_posts
    sql = <<~SQL
    SELECT  DISTINCT posts.id, posts.username, posts.time_of, posts.caption, 
    posts.song_link, count(likes.username) AS post_likes,
    count(comments.comment) AS post_comments FROM posts
    LEFT OUTER JOIN likes ON likes.post_id = posts.id
    LEFT OUTER JOIN comments ON comments.post_id = posts.id
    WHERE posts.time_of > current_date - interval '7 days'
    GROUP BY posts.id
    ORDER BY post_likes DESC
    LIMIT 100
    SQL
    result = @db.exec_params(sql)

    result.map do |tuple|
      {
        id: tuple["id"],
        username: tuple["username"],
        time_of_post: tuple["time_of"],
        caption: tuple["caption"],
        song_link: tuple["song_link"],
        likes: tuple["post_likes"],
        comments: tuple["post_comments"]
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

  def new_like?(username, post_id)
    sql = "SELECT username FROM likes WHERE username = $1 AND post_id = $2"
    result = @db.exec_params(sql, [username, post_id])
    result.values.empty?
  end

  def create_like(username, post_id)
    sql = "INSERT INTO likes(username, post_id) VALUES ($1, $2)"
    @db.exec_params(sql, [username, post_id])
  end

  def delete_like(username, post_id)
    sql = "DELETE FROM likes WHERE username = $1 AND post_id = $2"
    @db.exec_params(sql, [username, post_id])
  end

  def get_user_posts(username)
    sql = <<~SQL
    SELECT posts.id, posts.username, posts.time_of, posts.caption, 
    posts.song_link, count(likes.username) AS post_likes,
    count(comments.comment) AS post_comments FROM posts
    LEFT OUTER JOIN likes ON likes.post_id = posts.id
    LEFT OUTER JOIN comments ON comments.post_id = posts.id
    WHERE posts.username = $1
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
        likes: tuple["post_likes"],
        comments: tuple["post_comments"]
      }
    end
  end

  def get_user_stats(username)
    user = {
            username: '',
            follower_count: '',
            following_count: '',
            post_count: ''
            }
    sql = <<~SQL
    SELECT (SELECT users.username FROM users WHERE users.username = $1) AS username,
    (SELECT count(follows.follower) FROM follows WHERE follows.follower = $1) AS following_count,
    (SELECT count(follows.username) FROM follows WHERE follows.username = $1) AS follower_count,
    (SELECT count(posts.id) FROM POSTS WHERE posts.username = $1) AS post_count FROM follows
    LIMIT 1
    SQL
    
    result = @db.exec_params(sql, [username])
    result.each do |tuple|
      user[:username] = tuple["username"]
      user[:follower_count] = tuple["follower_count"]
      user[:following_count] = tuple["following_count"]
      user[:post_count] = tuple["post_count"]
    end
    user
  end

  def new_follow?(username, follower)
    sql = "SELECT username, follower FROM follows WHERE username = $1 AND follower = $2"
    result = @db.exec_params(sql, [username, follower])
    result.values.empty?
  end

  def create_follow(username, follower)
    sql = "INSERT INTO follows(username, follower) VALUES($1, $2)"
    @db.exec_params(sql, [username, follower])
  end

  def delete_follow(username, follower)
    sql = "DELETE FROM follows WHERE username = $1 AND follower = $2"
    @db.exec_params(sql, [username, follower])
  end

  private

  # Abstracts out manually creating debug lines each time we run an sql query.
  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end
end
