require 'sinatra'
require 'sinatra/content_for'
require 'securerandom'
require 'tilt/erubis'

require_relative 'validation_helpers'

SESSION_SECRET = '4ddd6082ade9e381c556063b42592b07d2777019fadb792c83eae8a0f3c47cf1'.freeze

START_ID = '0'.freeze
ERROR_NO_LIST = 'The list could not be found.'.freeze
ERROR_INVALID_LIST = 'The list name must be between 1 and 100 characters.'.freeze
ERROR_INVALID_TODO = 'The todo name must be between 1 and 100 characters.'.freeze
ERROR_EXISTING_NAME = "There\'s already a list with that name.".freeze
SUCCESS_MESSAGE = 'The list has been created.'.freeze
SUCCESS_UPDATE = 'The list has been updated.'.freeze
SUCCESS_TODO = 'The todo was added.'.freeze
SUCCESS_UPDATE_TODO = 'The todo has been updated.'.freeze
SUCCESS_COMPLETED_TODOS = 'All todos have been completed.'.freeze
SUCCESS_DELETED_TODO = 'The todo has been deleted.'.freeze
SUCCESS_DELETED_LIST = 'The list has been deleted.'.freeze

configure do
  enable :sessions
  # The session secret is a key used for signing and/or
  # encrypting cookies set by the application
  # to maintain session state. In other words, the symmetric key for
  # a symmetric encryption model of communication.
  set :session_secret, SESSION_SECRET

  set :erb, :escape_html => true
end

helpers do
  def find_list(id)
    session[:lists].find { |list| list[:id] == id }
  end
  
  def all_todos_completed?(list)
    list[:todos].all? { |todo| todo[:completed] }
  end
  
  def completed_todos(list)
    list[:todos].count { |todo| todo[:completed] }
  end

  def new_id(item)
    item.empty? ? START_ID : (item.last[:id].to_i + 1).to_s
  end

  def todos_stats(list)
    if list[:todos].empty? then '0'
    elsif all_todos_completed?(list) then "#{list[:todos].size}/#{list[:todos].size}"
    else
      "#{completed_todos(list)}/#{list[:todos].size}"
    end
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all the lists:
get '/lists' do
  @lists =
    session[:lists].sort_by do |list|
      (!all_todos_completed?(list) || list[:todos].empty?) ? 0 : 1
    end

  erb :lists
end

# Render the new list form:
get '/lists/new' do
  erb :new_list
end

# Create a new list:
post '/lists' do
  list_name = params[:list_name].strip

  validity = check(list_name)
  if validity == :valid
    session[:lists] << { name: list_name, id: new_id(session[:lists]), todos: [] }
    session[:success] = SUCCESS_MESSAGE
    redirect '/lists'
  else
    message = validity == :invalid_name ? ERROR_INVALID_LIST : ERROR_EXISTING_NAME
    session[:error] = message
    erb :new_list
  end
end

# Single list page:
get '/lists/:id' do |id|
  unless valid_id? id
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  @id = id
  @list = find_list(id)

  erb :single_list
end

# Edit list page:
get '/lists/:id/edit' do |id|
  unless valid_id? id
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  @id = id
  @list = find_list(@id)

  erb :edit
end

# Change list name:
post '/lists/:id' do |id|
  unless valid_id? id
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  new_name = params[:list_name]
  @id = id
  @list = find_list(id)
  validity = check(new_name)
  if validity == :valid
    @list[:name] = new_name
    session[:success] = SUCCESS_UPDATE
    redirect "/lists/#{id}"
  else
    message = validity == :invalid_name ? ERROR_INVALID_LIST : ERROR_EXISTING_NAME
    session[:error] = message
    erb :edit
  end
end

# Add todo to list
post '/lists/:id/todos' do |id|
  unless valid_id? id
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  @list = find_list(id)
  @id = id
  todo_name = params[:todo_name]
  if valid_todo? todo_name
    @list[:todos] << { id: new_id(@list[:todos]), name: todo_name, completed: false }
    session[:success] = SUCCESS_TODO

    redirect "/lists/#{id}"
  else
    session[:error] = ERROR_INVALID_TODO
    erb :single_list
  end
end

# Mark todo as completed:
post '/lists/:list_id/todos/:todo_id' do |list_id, todo_id|
  list = find_list(list_id)
  unless valid_id?(list_id) && valid_todo_id?(list, todo_id)
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  list[:todos].find { |todo| todo[:id] == todo_id }[:completed] = params[:completed] == 'true'
  session[:success] = SUCCESS_UPDATE_TODO
  redirect "/lists/#{list_id}"
end

# Mark all todos on a list as completed:
post '/lists/:id/complete_all' do |id|
  unless valid_id?(id)
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  find_list(id)[:todos].each { |todo| todo[:completed] = true }
  session[:success] = SUCCESS_COMPLETED_TODOS
  redirect "/lists/#{id}"
end

# Delete todo from a list:
post '/lists/:list_id/todos/:todo_id/delete' do |list_id, todo_id|
  list = find_list(list_id)

  unless valid_id?(list_id) && valid_todo_id?(list, todo_id)
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  list[:todos].delete_if { |todo| todo[:id] == todo_id }
  session[:success] = SUCCESS_DELETED_TODO
  redirect "/lists/#{list_id}"
end

# Delete list:
post '/lists/:id/delete' do |id|
  unless valid_id? id
    session[:error] = ERROR_NO_LIST
    redirect '/lists'
  end

  session[:lists].delete_if { |list| list[:id] == id }
  session[:success] = SUCCESS_DELETED_LIST
  redirect '/lists'
end
