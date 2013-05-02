#!/usr/bin/env ruby
require 'pty'
require 'timeout'

host='192.168.0.1'
port=22
lu_password='vanc0uver'
ru_password='vanc0uver'

def until_prompt( prompt )
	buffer= ""
	begin
		Timeout.timeout( 10 ) {
			loop do
				buffer << $out.getc.chr
				break if buffer =~ Regexp.new(prompt)
			end
		}
		buffer
	rescue
		printf buffer
	end	
end

PTY.spawn("ssh -p #{port} loginuser@#{host}") do |stdout,stdin,pid|
	$out=stdout
	printf until_prompt( 'password:' )
	stdin.printf( lu_password + "\n" )
	printf until_prompt( '/home/login >' )
	stdin.printf( "su\n" )
	printf until_prompt( 'Password:' )
	stdin.printf( "#{ru_password}\n" )
	printf until_prompt( '/home/login #' )
	stdin.printf( "cc get http\n" )
	printf until_prompt( ":/home/login #" )

	stdin.printf( "exit\n" )
	printf until_prompt( ":/home/login >" )
	stdin.printf( "exit\n" )
	#printf until_prompt( ":~$" )
  

end

