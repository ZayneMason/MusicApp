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
  if params[:new_password] != params[:confirm_password]
    session[:message] = "Please make sure passwords match."
    redirect "/users/create"
  elsif !@storage.valid_username?(params[:username])
    session[:message] = "Username is already taken."
    redirect "/users/create"
  elsif params[:username].length >= 19 || params[:username].length < 1
    session[:message] = "Please make sure username is 18 or less characters and not empty."
    redirect "/users/create"
  else
    @storage.create_user(params[:username], params[:password])
    session[:message] = "Account created. Welcome to music app."
    session[:username] = params[:username]
    redirect "/"
  end
end

get "/" do
  redirect "/users/login" unless session[:username]
  @posts = @storage.get_posts_for_list(session[:username])
  erb :post_list, layout: :layout
end


# DISPLAY A LIST OF POSTS FROM USERS USER FOLLOWS
# DISPLAY A LIST OF POSTS FROM USERS THAT THE USER DOES NOT FOLLOW
# LIKE OR COMMENT ON THESE POSTS
# FOLLOW NEW USERS
# CREATE AND DELETE POSTS
# VIEW LIKES AND COMMENTS ON A POST

after do
  @storage.disconnect
end
