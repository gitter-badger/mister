require 'sinatra'

redis = nil

configure do
	require 'redis'
	dns = "pub-redis-11457.us-east-1-1.2.ec2.garantiadata.com"
	port = "11457"
	redis = Redis.new(:host => dns, :port => port)
end

get '/' do 
	erb :new
end

post '/' do
	@shortened = params[:key]
	@url = params[:url]
	redis.set 'urls:' + @shortened, params[:url]
	erb :new
end

get '/:shortened' do
	redirect redis.get 'urls:' + params[:shortened] 
end
