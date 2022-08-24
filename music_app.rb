require "tilt/erubis"
require "sinatra"
require "sinatra/content_for"

require_relative "database_persistance.rb"

configure do
  enable :sessions
  set :session_secret, "1"
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistance.rb"
end

before do
  @storage = DatabasePersistance.new(logger)
end

helpers do
  def following?(user_to_follow, username)
    @storage.new_follow?(user_to_follow, username) == false
  end

  def liked?(username, post_id)
    @storage.new_like?(username, post_id) == false
  end
end


def valid_login?(username, password)
  @storage.valid_user?(username, password)
end

def valid_link?(link)
  link.include?("https://www.youtube.com/watch?") ||
  link.include?("https://youtube.com/playlist?") ||
  link.include?("https://open.spotify.com/track") ||
  link.include?("https://open.spotify.com/playlist/")
end

# LOG IN TO USER
get "/users/login" do
  erb :login, layout: :layout
end

post "/users/login" do
  if @storage.valid_user?(params[:username], params[:password])
    session[:message] = "You are now logged in as #{params[:username]}"
    session[:username] = params[:username]
    redirect session[:current_path]
  else
    session[:error] = "Invalid username/password. Please try again."
    redirect "/users/login"
  end
end

# LOG OUT OF USER
post "/logout" do
  session.delete(:username)
  redirect "/users/login"
end

# CREATE NEW USER
get "/users/create" do
  erb :signup, layout: :layout
end

post "/users/create" do
  if @storage.valid_username?(params[:username]) == false
    session[:error] = "Username is already taken."
    redirect "/users/create"
  elsif params[:username].length > 18 || params[:username].length < 1
    session[:error] = "Please make sure username is between 1 and 18 characters long."
    redirect "/users/create"
  end
  @storage.create_user(params[:username], params[:new_password])
  redirect "/"
end

# DISPLAY A LIST OF POSTS 
get "/" do
  redirect "/users/login" unless session[:username]
  @posts = @storage.get_posts_for_list(session[:username])
  erb :post_list, layout: :layout
end

get "/browse" do
  @posts = @storage.get_top_posts
  erb :top_posts_of_week, layout: :layout
end

# CREATE A NEW POST
get "/users/posts/new" do
  redirect "/users/login" unless session[:username]
  erb :create_post, layout: :layout
end

post "/users/posts/new" do
  redirect "/users/login" unless session[:username]

  if params[:caption].length > 140
    session[:error] = "Please make sure caption is 140 characters or less."
    redirect "/users/posts/new"
  elsif valid_link?(params[:song_link]) == false
    session[:error] = "Please make sure that the link provided is a valid Spotify or Youtube link."
    redirect "/users/posts/new"
  end

  @storage.create_post(params[:song_link], params[:caption], session[:username])
  session[:message] = "Post created!"
  redirect "/"
end

# DELETE A POST
post "/posts/:post_id/delete" do
  redirect back unless @storage.post_belong_to_user?(session[:username], params[:post_id])
  @storage.delete_post(params[:post_id])
  session[:message] = "Post has been removed."
  redirect "/"
end


# VIEW THREAD OF A SINGLE POST
get "/posts/:post_id" do
  redirect "/users/login" unless session[:username]
  @post = @storage.get_post_thread(params[:post_id])
  erb :single_post, layout: :layout
end

# ADD A COMMENT TO A POST'S THREAD
post "/posts/:post_id/comments" do
  redirect "/users/login" unless session[:username]
  if params[:new_comment].length > 140
    session[:error] = "Please keep comments 140 characters or less."
    redirect back
  elsif params[:new_comment].length == 0
    session[:error] = "Please make sure comment box is not empty."
    redirect back
  end
  @storage.create_comment(session[:username], params[:post_id], params[:new_comment])
  session.delete(:new_comment)
  session[:message] = "Comment posted."
  redirect back
end

# LIKE A POST
post "/posts/:post_id/likes" do
  redirect "/users/login" unless session[:username]
  if @storage.new_like?(session[:username], params[:post_id])
    @storage.create_like(session[:username], params[:post_id])
  else
    @storage.delete_like(session[:username], params[:post_id])
  end
  redirect back
end

# VIEW A SPECIFIC USER'S PROFILE
get "/users/:username" do
  session[:current_path] = request.path_info
  @user_posts = @storage.get_user_posts(params[:username])
  @user_stats = @storage.get_user_stats(params[:username])
  erb :user, layout: :layout
end

# FOLLOW A USER
post "/users/:username/follow" do
  redirect "/users/login" unless session[:username]
  user_to_follow = params[:username]
  if @storage.new_follow?(user_to_follow, session[:username])
    @storage.create_follow(user_to_follow, session[:username])
  else
    @storage.delete_follow(user_to_follow, session[:username])
  end
  redirect back
end

# FEATURE TO SEARCH FOR USERS BASED ON USERNAME
post "/search" do
  session[:search_results] = @storage.search_users(params[:search])
  redirect "/search_results"
end

get "/search_results"  do
  @search_results = session.delete(:search_results)
  erb :search_results, layout: :layout
end

after do
  @storage.disconnect
end
