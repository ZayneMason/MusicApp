require "tilt/erubis"
require "sinatra"
require "sinatra/content_for"
require "bcrypt"

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
# CREATE A NEW USER
# LOG IN TO USER
# DISPLAY A LIST OF POSTS FROM USERS USER FOLLOWS
# DISPLAY A LIST OF POSTS FROM USERS THAT THE USER DOES NOT FOLLOW
# LIKE OR COMMENT ON THESE POSTS
# FOLLOW NEW USERS
# CREATE AND DELETE POSTS
# VIEW LIKES AND COMMENTS ON A POST

after do
  @storage.disconnect
end
