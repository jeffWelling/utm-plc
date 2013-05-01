#!/usr/bin/env ruby
require 'net/ssh'
require 'pty'

host='192.168.0.1'
lu_password='vanc0uver'
ru_password=''

Net::SSH.start( host, 'loginuser', :password=>lu_password ) {|ssh|
	puts ssh.PTY.spawn "echo 'hello world'"	
	http= ssh.exec!( 'cc get http' )
}

def till_prompt( prompt, cout )
	buffer= ""
	loop {
		buffer << cout.getc.chr
		break if buffer =~ /Password:/
	}
	buffer
end
