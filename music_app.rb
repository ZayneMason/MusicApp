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
    redirect "/"
  else
    session[:message] = "Invalid username/password. Please try again."
    redirect "/users/login"
  end
end

# CREATE NEW USER
get "/users/create" do
  erb :signup, layout: :layout
end

post "/users/create" do
  if @storage.valid_username?(params[:username]) == false
    session[:message] = "Username is already taken."
    redirect "/users/create"
  elsif params[:username].length > 18 || params[:username].length < 1
    session[:message] = "Please make sure username is between 1 and 18 characters long."
    redirect "/users/create"
  end
  @storage.create_user(params[:username], params[:new_password])
  redirect "/"
end

# DISPLAY A LIST OF POSTS FROM USERS USER FOLLOWS
get "/" do
  redirect "/users/login" unless session[:username]
  @posts = @storage.get_posts_for_list(session[:username])
  erb :post_list, layout: :layout
end

get "/users/posts/new" do
  redirect "/users/login" unless session[:username]
  erb :create_post, layout: :layout
end

# CREATE A NEW POST
post "/users/posts/new" do
  redirect "/users/login" unless session[:username]

  if params[:caption].length > 140
    session[:message] = "Please make sure caption is 140 characters or less."
    redirect "/users/posts/new"
  elsif valid_link?(params[:song_link]) == false
    session[:message] = "Please make sure that the link provided is a valid Spotify or Youtube link."
    redirect "/users/posts/new"
  end

  @storage.create_post(params[:song_link], params[:caption], session[:username])
  session[:message] = "Post created!"
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
    session[:message] = "Please keep comments 140 characters or less."
    redirect back
  elsif params[:new_comment].length == 0
    session[:message] = "Please make sure comment box is not empty."
    redirect back
  end
  @storage.create_comment(session[:username], params[:post_id], params[:new_comment])
  redirect back
end

after do
  @storage.disconnect
end
