# encoding: utf-8
require 'sinatra'

redis = nil

configure do
	require 'redis'
	dns = ENV['dns'] || "127.0.0.1"
	port = ENV['p'] || "6379"
	redis = Redis.new(:host => dns, :port => port)
	enable :sessions
end

helpers do
	def authenticated?
		session[:email] != nil
	end
end

get '/' do 
	if authenticated?
		session[:keys] = redis.lrange 'keys:' + session[:email], 0, -1
		ans = "<table><tr> <th>Url</th> <th>key</th> <th>count</th></tr>"
		session[:keys].each do |k|
			url = redis.get 'user:'+ session[:email] + ':key:' + k
			count = redis.get 'user:'+ session[:email] + ':key:' + k + ':count'
			ans += "<tr> 
						<td>#{url}</td>
						<td><a href='/#{k}' target=_blank>#{k}</a></td>
						<td>#{count}</td>
					</tr>"
		end
		ans += "</table>"
		@total = ans unless session[:keys] == []
		erb :new
	else
		erb :signin
	end
end

get '/a/logout' do
	session[:email] = nil
	session[:message] = ""
	erb :signin
end

get '/a/signup' do
	session[:message] = ""
	erb :signup
end

get '/a/signin' do
	session[:message] = ""
	erb :signin
end

post '/a/signup' do
	if !(redis.get 'user:' + params[:email])
		redis.set 'user:' + params[:email], Time.now
		redis.set 'user:' + params[:email] + ':pass', params[:pass]
		redis.set 'user:' + params[:email] + ':user', params[:name]
		session[:email] = params[:email]
		redirect '/'
	else
		session[:message] = "username ya esta registrado"
		erb :signup
	end
end

post '/a/signin' do
	p = redis.get 'user:' + params[:email] + ':pass'
	if p == params[:pass]
		session[:email] = params[:email]
	else
		session[:message] = "usuario y/o contraseña invalidos"
	end
	redirect '/'
end

post '/new' do
	if authenticated?
		@key = params[:key]
		@url = params[:url]
		url = redis.get 'user:'+ session[:email] + ':key:' + @key # url de key
		key = redis.get 'user:'+ session[:email] + ':url:' + @url # key de url
		session[:message] = if (@key =~ /[^A-Za-z0-9\_-]/)!=nil # key ya existe o invalida
								"La key : #{@key} no es valida"
							elsif key || url
								(key ? "La url : #{@url}, ya fue acortada<br>" : "") + ( url ? "La key : #{@key}, ya fue usada": "")
							else	
								redis.set 'user:' + session[:email] + ':key:' + @key, @url
								redis.set 'user:' + session[:email] + ':url:' + @url, @key
								redis.set 'user:' + session[:email] + ':key:' + @key +':count', 0
								redis.rpush 'keys:' + session[:email], @key
							end
	end
	redirect '/'
end

get '/:key' do
	url = redis.get 'user:' + session[:email] + ':key:' + params[:key] 
	if url 
		redis.incr 'user:' + session[:email] + ':key:' + params[:key] + ':count'
		redirect url
	else
		session[:message] = "Url no encontrada"
		redirect '/'
	end
end
