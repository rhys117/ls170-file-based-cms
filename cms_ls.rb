require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

root = File.expand_path("..", __FILE__)

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

  def load_file_content(path)
    content = File.extname(path)
    case File.extname(path)
    when ".txt"
      headers["Content-Type"] = "text/plain"
      content
    when ".md"
      render_markdown(content)
    end
  end
end

get "/" do
  @files = Dir[root + "/data/*"].map do |file|
    File.basename(file)
  end

  erb :index
end

get "/:file" do
  file_path = root + "/data/" + params[:file]

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file]} does not exist."
    redirect "/"
  end
end


get "/:file/edit" do
  file_path = root + "/data/" + params[:file]

  @file = params[:file]
  @content = File.read(file_path)

  erb :edit
end

post "/:file" do
  file_path = root + "/data/" + params[:file]

  File.write(file_path, params[:content])

  session[:success] = "#{params[:file]} has been updated"
end
