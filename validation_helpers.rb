def check(name)
  valid_name = name.match?(/\w{1,100}/)
  unique_name = session[:lists].none? { |list| list[:name] == name }

  if valid_name && unique_name then :valid
  elsif !valid_name then :invalid_name
  else
    :existing_name
  end
end

def valid_todo?(todo)
  todo.match?(/\w{1,100}/)
end

def new_id(item)
  if item.empty? then START_ID
  else
    (item.last[:id].to_i + 1).to_s
  end
end

def valid_id?(id)
  session[:lists].any? { |list| list[:id] == id }
end

def valid_todo_id?(list, id)
  return false if list.nil?

  list[:todos].any? { |todo| todo[:id] == id }
end

def find_list(id)
  session[:lists].find { |list| list[:id] == id }
end

def all_todos_completed?(list)
  list[:todos].all? { |todo| todo[:completed] }
end

def completed_todos(list)
  list[:todos].count { |todo| todo[:completed] }
end