require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, "1"
end

