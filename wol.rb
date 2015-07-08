# Coding: UTF-8
require 'twitter'
require 'expect'
require 'net/telnet'

###設定###
	consumer_key = ""
	consumer_secret = ""
	access_token = ""
	access_secret = ""
	@reg1 = /C:\\Users\\hoge-user1>/
	@reg2 = /C:\\Users\\hoge-user2>/

	#PC1
		IP1 = ''
		mac1 = ''
		user1 = ''
		pass1 = ''

	#PC2
		IP2 = ''
		mac2 = ''
		user2 = ''
		pass2 = ''
###ここまで###

def wake(mac)
  mes = ['FF'].pack('H2') * 6
  mes << mac.split(':').pack('H2H2H2H2H2H2') * 16
  s = UDPSocket.new
  s.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, 1)
  s.send(mes, 0, '<broadcast>', 7)
end

def telnet(address, username, password, reg)
  telnet = Net::Telnet.new("Host" => address) {|c| print c}
  telnet.login(username, password) {|c, w| c.match(reg) { telnet.cmd('rundll32.exe PowrProf.dll,SetSuspendState') {telnet.cmd("exit") {|c| print c}} }}
	telnet.close
end

@rest_client = Twitter::REST::Client.new do |config|
  config.consumer_key        = consumer_key
  config.consumer_secret     = consumer_secret
  config.access_token        = access_token
  config.access_token_secret = access_secret
end

@stream_client = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = consumer_key
  config.consumer_secret     = consumer_secret
  config.access_token        = access_token
  config.access_token_secret = access_secret
end

@orig_name, @screen_name = [:name, :screen_name].map{|x| @rest_client.user.send(x) }
@regexp1 = /^@#{@screen_name}\s+main_wol/
@regexp2 = /^@#{@screen_name}\s+sub_wol/
@regexp3 = /^@#{@screen_name}\s+main_sleep/
@regexp4 = /^@#{@screen_name}\s+sub_sleep/
@regexp = /(#{@regexp1}|#{@regexp2}|#{@regexp3}|#{@regexp4})/

def function(status)
  if status.user.id == @rest_client.user.id
	if status.text.match(@regexp1)
		wake(mac1)
		text = "メイン機WOLしました"
	elsif status.text.match(@regexp2)
		wake(mac2)
		text = "サブ機WOLしました"
	elsif status.text.match(@regexp3)
		telnet(IP1, user1, pass1, @reg1)
		text = "メイン機SLEEPしました"
	elsif status.text.match(@regexp4)
		telnet(IP2, user2, pass2, @reg2)
		text = "サブ機SLEEPしました"
	end
 else
		text = "自分専用コマンドです。"
 end
 @rest_client.update("@#{status.user.screen_name} #{text} #{@day}", :in_reply_to_status_id => status.id)
end

def event(status) #sourceはふぁぼした人　targetがふぁぼされた人
	case status.name.to_s
	when "follow"
		return
	when "unfollow"
		return
	when "unfavorite"
		return
	when "favorite"
	  time = Time.now
	  day = time.strftime("%m/%d %H:%M:%S")
	  if status.target.id == 1087220629
			return if status.target_object.text == nil
			if status.target_object.text.match(/@[0-9a-z_]{1,15}/i)
				return
			end
	    tweet = status.target_object.text
	    if tweet.size > 110
	      tweet = tweet[0, 110]
	    end
	    
	    if status.source.id == 3011304019
	      text = "のあちゃんが\n「#{tweet}」\nを学習した！\n(#{day})"
	      ##text = "のあちゃんが\n「」\nを学習した！\n(#{@day})"
	    elsif status.source.id == 2837622288
	      text = "ゆあちゃんが\n「#{tweet}」\nを学習した！\n(#{day})"
			elsif status.source.id == 3195466464
				text = "ももかちゃんが\n「#{tweet}」\nを学習した！\n(#{day})"
			else
				return
	    end
	    if (rand(7) == 0)
	      @rest_client.update(text)
	    end
	  end
	end
end

@stream_client.user do |object|
	begin
    case object
        when Twitter::Tweet
          unless object.text.start_with? "RT"
            if object.text.match(@regexp)
              function(object)
            end
          end
        when Twitter::Streaming::Event
          #event(object)
        when Twitter::Streaming::FriendList
        when Twitter::Streaming::DeletedTweet
        end
	rescue
		error = File.open("./error.txt", "a")
		error.puts $!.message
		error.puts $!.backtrace
		error.puts ("\n\n")
		error.close
	end
end
