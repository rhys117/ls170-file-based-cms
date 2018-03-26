require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

SUPPORTED_FILETYPES = [".md", ".txt"]

def filetype_supported?(file)
  SUPPORTED_FILETYPES.include?(File.extname(file))
end

def data_path
  if ENV["RACK_ENV"] == 'test'
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session[:username]
  # session.key?(:username)
end

def redirect_unless_signed_in
  unless user_signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

configure do
  enable :sessions
  set :session_secret, 'session secret key'
end

helpers do
  def remove_extentions(file)
    File.basename(file, ".*")
  end

  def render_markdown(file)
    markdown = Redcarpet:: Markdown.new(Redcarpet::Render::HTML)
    markdown.render(file)
  end

  def render_txt(content)
    headers["Content-Type"] = "text/plain"
    headers["Content"] = content
  end

  def load_file_content(path)
    content = File.read(path)
    ext = File.extname(path)

    return render_txt(content) if ext ==".txt"
    erb render_markdown(content) if ext == ".md"

    # case ext
    # when ".txt"
    #   render_txt(content)
    # when ".md"
    #   render_markdown(content)
    # end
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |file|
    File.basename(file)
  end

  erb :index
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  credentials = load_user_credentials
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end

get "/new" do
  redirect_unless_signed_in

  erb :new
end

post "/create" do
  redirect_unless_signed_in

  file = params[:filename].to_s

  if file.size == 0
    session[:error] = "A name is required"
    status 422
    erb :new
  elsif filetype_supported?(file)
    file_path = File.join(data_path, file)

    File.write(file_path, "")
    session[:success] = "#{params[:filename]} has been created"

    redirect "/"
  else
    session[:error] = "Filetype not supported. Must be .txt or .md"
    status 422
    erb :new
  end
end

get "/:file" do
  file_path = File.join(data_path, params[:file])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file]} does not exist."
    redirect "/"
  end
end

get "/edit/:file" do
  redirect_unless_signed_in

  file_path = File.join(data_path, params[:file])

  @filename = params[:file]
  @content = File.read(file_path)

  erb :edit
end

post "/delete/:file" do
  redirect_unless_signed_in

  file_path = File.join(data_path, params[:file])

  File.delete(file_path)

  session["success"] = "#{params[:file]} has been deleted."
  redirect("/")
end

post "/:file" do
  redirect_unless_signed_in

  file_path = File.join(data_path, params[:file])

  File.write(file_path, params[:content])

  session[:success] = "#{params[:file]} has been updated"
  redirect("/")
end
