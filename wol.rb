# Coding: UTF-8
require 'twitter'
require 'expect'
require 'net/telnet'

###Raspberry_PI以外でこのプログラムを使用する場合は"require 'pi_piper'"とpiperメソッドの""中身""をコメントアウトしてください。
require 'pi_piper'
def piper(pin)
  pin_a = PiPiper::Pin.new :pin => pin, :direction => :out
  pin_a.on
  pin_a.off
end

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
  config.consumer_key        = ""
  config.consumer_secret     = ""
  config.access_token        = ""
  config.access_token_secret = ""
end

@stream_client = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = ""
  config.consumer_secret     = ""
  config.access_token        = ""
  config.access_token_secret = ""
end

@orig_name, @screen_name = [:name, :screen_name].map{|x| @rest_client.user.send(x) }
@reg = [
  /^@#{@screen_name}\s+main_wol/,
  /^@#{@screen_name}\s+sub_wol/,
  /^@#{@screen_name}\s+main_sleep/,
  /^@#{@screen_name}\s+sub_sleep/,
  /^@#{@screen_name}\s+main_reboot/,
  /^@#{@screen_name}\s+sub_reboot/,
  ]
@regexp = Regexp.union(@reg)
@reg1 = /C:\\Users\\hoge-user>/
@reg2 = /C:\\Users\\foo-user>/

def function(status)
  if status.user.id == twitter_user_id
    case status.text
    when @reg[0]
  		wake(mac_address)
  		text = "メイン機WOLしました。"
    when @reg[1]
      wake(mac_address)
  		text = "サブ機WOLしました。"
    when @reg[2]
      telnet(ip, user, password, @reg1)
  		text = "メイン機SLEEPしました。"
    when @reg[3]
      telnet(ip, user, password, @reg2)
  		text = "サブ機SLEEPしました。"
    when @reg[4]
      piper(4)
      text = "メイン機強制再起動しました。"
    when @reg[5]
      piper(17)
      text = "サブ機強制再起動しました。"
    end
	else
		text = "自分専用コマンドです。"
	end
	  @rest_client.update("@#{status.user.screen_name} #{text} #{@day}", :in_reply_to_status_id => status.id)
end

@stream_client.user do |object|
	begin
    case object
    when Twitter::Tweet
      unless object.text.start_with? "RT"
        if object.text.match(@regexp)
          Thread.new{function(object)}
        end
      end
    when Twitter::Streaming::Event
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
